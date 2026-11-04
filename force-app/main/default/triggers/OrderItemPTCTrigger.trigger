trigger OrderItemPTCTrigger on OrderItem (before insert, before update) {
    // Intercept Revenue Cloud Instant Pricing before it commits PricingTermCount as a
    // rounded integer. We compute the decimal value from ServiceDate/EndDate and assign
    // it directly to Trigger.new — Salesforce commits our value, not RC's integer.
    //
    // Runs on every before-insert/before-update, including RC's own follow-up saves —
    // unlike a record-triggered Flow reacting to this same change, a trigger has no
    // "fires once per transaction" limit, so it reliably wins even if RC rewrites
    // PricingTermCount more than once in the same transaction.
    //
    // Prefers the linked QuoteLineItem's own PricingTermCount when available (same
    // precedence as SetOrderItemPricingTerm.calcPTC) so ramp/MTM lines whose QLI value
    // is intentionally different from a pure date-based calc (e.g. 0.98, not 1.0) are
    // not overwritten with the wrong number.

    Set<Id> psmIds = new Set<Id>();
    Set<Id> qliIds = new Set<Id>();
    for (OrderItem oi : Trigger.new) {
        if (oi.ProductSellingModelId != null) psmIds.add(oi.ProductSellingModelId);
        if (oi.QuoteLineItemId != null) qliIds.add(oi.QuoteLineItemId);
    }
    Map<Id, String> psmTypeMap = new Map<Id, String>();
    if (!psmIds.isEmpty()) {
        for (ProductSellingModel psm : [
            SELECT Id, SellingModelType FROM ProductSellingModel WHERE Id IN :psmIds
        ]) psmTypeMap.put(psm.Id, psm.SellingModelType);
    }
    Map<Id, Decimal> qliPtcMap = new Map<Id, Decimal>();
    if (!qliIds.isEmpty()) {
        for (QuoteLineItem qli : [
            SELECT Id, PricingTermCount FROM QuoteLineItem WHERE Id IN :qliIds
        ]) qliPtcMap.put(qli.Id, qli.PricingTermCount);
    }

    for (OrderItem oi : Trigger.new) {
        if (oi.ServiceDate == null || oi.EndDate == null) continue;
        String modelType = oi.ProductSellingModelId != null ? psmTypeMap.get(oi.ProductSellingModelId) : null;
        if ('OneTime'.equalsIgnoreCase(modelType)) continue;

        Decimal qliPtc = oi.QuoteLineItemId != null ? qliPtcMap.get(oi.QuoteLineItemId) : null;
        Decimal ptc;
        if (qliPtc != null && qliPtc > 0) {
            ptc = qliPtc;
        } else {
            // calcPTC: fullMonths + remainingDays/daysInMonth
            Integer fullMonths = oi.ServiceDate.monthsBetween(oi.EndDate);
            Date    base       = oi.ServiceDate.addMonths(fullMonths);
            while (fullMonths > 0 && base > oi.EndDate) {
                fullMonths--;
                base = oi.ServiceDate.addMonths(fullMonths);
            }
            Integer remainDays  = base.daysBetween(oi.EndDate.addDays(1));
            Date    monthStart  = Date.newInstance(base.year(), base.month(), 1);
            Integer daysInMonth = monthStart.daysBetween(monthStart.addMonths(1));
            ptc = fullMonths + (Decimal) remainDays / daysInMonth;
        }

        if (ptc != oi.PricingTermCount) {
            oi.PricingTermCount = ptc;
        }
    }
}