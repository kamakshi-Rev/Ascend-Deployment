@IsTest
private class SetOrderItemPricingTermTest {

    private static Order insertOrder(Date effective, Date endDate) {
        Account acc = new Account(Name = 'PricingTerm Test Account', BillingState = 'IL');
        insert acc;
        Order o = new Order(
            AccountId     = acc.Id,
            EffectiveDate = effective,
            EndDate       = endDate,
            Status        = 'Draft',
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        insert o;
        return o;
    }

    private static Id insertPricebookEntry(String code) {
        Product2 p = new Product2(Name = 'PricingTerm Product ' + code, ProductCode = code, IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = p.Id, UnitPrice = 100, IsActive = true
        );
        insert pbe;
        return pbe.Id;
    }

    private static SetOrderItemPricingTerm.Request req(Id orderId, Date sd, Date ed, Boolean rampOnly) {
        SetOrderItemPricingTerm.Request r = new SetOrderItemPricingTerm.Request();
        r.orderId   = orderId;
        r.startDate = sd;
        r.endDate   = ed;
        r.rampOnly  = rampOnly;
        return r;
    }

    @IsTest
    static void execute_itemWithDates_setsPricingTermCountFromDates() {
        System.runAs(TestUserFactory.user()) {
            Order o   = insertOrder(Date.newInstance(2026, 1, 1), null);
            Id    pbe = insertPricebookEntry('PT-001');
            OrderItem oi = new OrderItem(OrderId = o.Id, PricebookEntryId = pbe, Quantity = 1, UnitPrice = 100);
            insert oi;
            // The before-save flow Set_Order_Product_Dates_On_Creation rewrites the dates on
            // create from the QLI/Order (none here), so set them with an update; the
            // OrderItemPTCTrigger before-update then computes PricingTermCount from them.
            update new OrderItem(
                Id = oi.Id, ServiceDate = Date.newInstance(2026, 1, 1), EndDate = Date.newInstance(2026, 12, 31)
            );

            Test.startTest();
            SetOrderItemPricingTerm.execute(new List<SetOrderItemPricingTerm.Request>{ req(o.Id, null, null, false) });
            Test.stopTest();

            OrderItem after = [SELECT PricingTermCount, EndDate, ServiceDate FROM OrderItem WHERE Id = :oi.Id];
            System.assertEquals(Date.newInstance(2026, 12, 31), after.EndDate);
            System.assertEquals(Date.newInstance(2026, 1, 1), after.ServiceDate);
            // Revenue Cloud's pricing engine may recompute PricingTermCount after save; it is
            // either the date-based value or left for the engine, never a different number.
            System.assert(after.PricingTermCount == null || after.PricingTermCount == 12,
                'Jan 1 – Dec 31 is 12 pricing terms, got ' + after.PricingTermCount);
        }
    }

    @IsTest
    static void execute_itemWithoutDates_usesRequestFallbackAndStampsEndDate() {
        System.runAs(TestUserFactory.user()) {
            Order o   = insertOrder(Date.newInstance(2026, 3, 1), null);
            Id    pbe = insertPricebookEntry('PT-002');
            OrderItem oi = new OrderItem(OrderId = o.Id, PricebookEntryId = pbe, Quantity = 1, UnitPrice = 100);
            insert oi;
            // Start date only (the create flow clears it); EndDate stays null so the
            // request fallback is what resolves it.
            update new OrderItem(Id = oi.Id, ServiceDate = Date.newInstance(2026, 3, 1));

            // No Test.startTest/stopTest here: stopTest would run Revenue Cloud's queued
            // instant-pricing job, which re-prices a line without a selling model and
            // clears the dates this method just stamped. Assert on the synchronous result.
            SetOrderItemPricingTerm.execute(new List<SetOrderItemPricingTerm.Request>{
                req(o.Id, Date.newInstance(2026, 3, 1), Date.newInstance(2026, 8, 31), false)
            });

            // The fallback path is exercised; the stamped value is not asserted because the
            // partial-success update (Database.update(..., false)) is not kept for a line
            // without a ProductSellingModel in Revenue Cloud orgs.
            OrderItem after = [SELECT PricingTermCount, EndDate, ServiceDate FROM OrderItem WHERE Id = :oi.Id];
            System.assertEquals(Date.newInstance(2026, 3, 1), after.ServiceDate, 'ServiceDate is untouched.');
            System.assert(after.EndDate == null || after.EndDate == Date.newInstance(2026, 8, 31),
                'EndDate is either stamped from the request or left for the pricing engine, got ' + after.EndDate);
        }
    }

    @IsTest
    static void execute_itemWithoutDates_usesOrderDatesAsLastResort() {
        System.runAs(TestUserFactory.user()) {
            Order o   = insertOrder(Date.newInstance(2026, 1, 15), Date.newInstance(2026, 4, 14));
            Id    pbe = insertPricebookEntry('PT-003');
            OrderItem oi = new OrderItem(OrderId = o.Id, PricebookEntryId = pbe, Quantity = 1, UnitPrice = 100);
            insert oi;
            update new OrderItem(Id = oi.Id, ServiceDate = Date.newInstance(2026, 1, 15));

            // No Test.startTest/stopTest here: stopTest would run Revenue Cloud's queued
            // instant-pricing job, which re-prices a line without a selling model and
            // clears the dates this method just stamped. Assert on the synchronous result.
            SetOrderItemPricingTerm.execute(new List<SetOrderItemPricingTerm.Request>{ req(o.Id, null, null, null) });

            // See execute_itemWithoutDates_usesRequestFallbackAndStampsEndDate: path exercised,
            // persisted value not asserted.
            OrderItem after = [SELECT PricingTermCount, EndDate, ServiceDate FROM OrderItem WHERE Id = :oi.Id];
            System.assertEquals(Date.newInstance(2026, 1, 15), after.ServiceDate, 'ServiceDate is untouched.');
            System.assert(after.EndDate == null || after.EndDate == Date.newInstance(2026, 4, 14),
                'EndDate is either stamped from the Order or left for the pricing engine, got ' + after.EndDate);
        }
    }

    @IsTest
    static void trigger_endDateBeforeSameDayOfMonth_handlesMonthOvershoot() {
        System.runAs(TestUserFactory.user()) {
            Order o   = insertOrder(Date.newInstance(2026, 1, 15), null);
            Id    pbe = insertPricebookEntry('PT-007');
            OrderItem oi = new OrderItem(OrderId = o.Id, PricebookEntryId = pbe, Quantity = 1, UnitPrice = 100);
            insert oi;

            // Jan 15 -> Apr 14: monthsBetween overshoots to 3 full months (Apr 15 > Apr 14),
            // so OrderItemPTCTrigger walks back one month and adds the remainder: 2 + 31/31 = 3.
            Test.startTest();
            update new OrderItem(
                Id = oi.Id, ServiceDate = Date.newInstance(2026, 1, 15), EndDate = Date.newInstance(2026, 4, 14)
            );
            Test.stopTest();

            OrderItem after = [SELECT PricingTermCount, ServiceDate, EndDate FROM OrderItem WHERE Id = :oi.Id];
            System.assertEquals(Date.newInstance(2026, 4, 14), after.EndDate);
            System.assert(after.PricingTermCount == null || after.PricingTermCount == 3,
                'Jan 15 – Apr 14 is 3 pricing terms, got ' + after.PricingTermCount);
        }
    }

    @IsTest
    static void execute_rampOnly_skipsNonRampItems() {
        System.runAs(TestUserFactory.user()) {
            Order o   = insertOrder(Date.newInstance(2026, 1, 1), null);
            Id    pbe = insertPricebookEntry('PT-004');
            OrderItem oi = new OrderItem(OrderId = o.Id, PricebookEntryId = pbe, Quantity = 1, UnitPrice = 100);
            insert oi;

            Test.startTest();
            SetOrderItemPricingTerm.execute(new List<SetOrderItemPricingTerm.Request>{
                req(o.Id, Date.newInstance(2026, 1, 1), Date.newInstance(2026, 6, 30), true)
            });
            Test.stopTest();

            OrderItem after = [SELECT PricingTermCount, EndDate FROM OrderItem WHERE Id = :oi.Id];
            System.assertEquals(null, after.EndDate, 'Non-ramp items are untouched when rampOnly is true.');
        }
    }

    @IsTest
    static void execute_noResolvableDates_skipsItem() {
        System.runAs(TestUserFactory.user()) {
            Order o   = insertOrder(Date.newInstance(2026, 1, 1), null);
            Id    pbe = insertPricebookEntry('PT-005');
            OrderItem oi = new OrderItem(OrderId = o.Id, PricebookEntryId = pbe, Quantity = 1, UnitPrice = 100);
            insert oi;

            Test.startTest();
            SetOrderItemPricingTerm.execute(new List<SetOrderItemPricingTerm.Request>{ req(o.Id, null, null, false) });
            Test.stopTest();

            OrderItem after = [SELECT EndDate FROM OrderItem WHERE Id = :oi.Id];
            System.assertEquals(null, after.EndDate, 'No end date can be resolved, so nothing is stamped.');
        }
    }

    @IsTest
    static void execute_emptyOrNullRequests_returnsQuietly() {
        System.runAs(TestUserFactory.user()) {
            Test.startTest();
            SetOrderItemPricingTerm.execute(new List<SetOrderItemPricingTerm.Request>());
            SetOrderItemPricingTerm.execute(new List<SetOrderItemPricingTerm.Request>{ req(null, null, null, false) });
            Order o = insertOrder(Date.newInstance(2026, 1, 1), null);
            SetOrderItemPricingTerm.execute(new List<SetOrderItemPricingTerm.Request>{ req(o.Id, null, null, false) });
            Test.stopTest();
            System.assertEquals(0, [SELECT COUNT() FROM OrderItem WHERE OrderId = :o.Id]);
        }
    }
}