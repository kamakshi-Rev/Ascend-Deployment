/**
 * Flags the NON-first segments of a quote so Booked MRR can count only the
 * first segment (Year 1) of a ramp.
 *
 * RULE (validated on pilot 230/230 and prod 17/17 quotes with dated groups):
 *   - Only QuoteLineGroups with a StartDate compete to be first.
 *   - The first segment is the earliest StartDate; SortOrder and then Id only
 *     break ties. Segment NAMES are not used - the org carries "Year 1",
 *     "Year 1 - Amend", "Segment 1", "Ramp 1", "Ramp Group" ... for the
 *     first segment. Amendments are covered because RCA gives the amended
 *     segment the lowest SortOrder (-999999999) and the earliest StartDate.
 *   - A quote with no dated group (plain non-ramp quote, or an undated
 *     container such as "3 Year Ramp Schedule" on its own) has no later
 *     segment at all.
 *
 * The stored flag is Is_Later_Segment__c (true = NOT the first segment) and
 * not "is first", so records that were never evaluated (older service lines,
 * non-ramp lines, quotes without groups) default to false and keep counting.
 *
 * Runs from two flows on QuoteLineGroup: create/update (StartDate or
 * SortOrder changed) and before-delete. At before-delete the deleted group
 * still exists, so it is passed as excludeGroupId and ignored.
 *
 * SAFETY: an uncaught exception here would roll back the ramp save, so every
 * path is wrapped and DML is partial-success. Failures land in faultLog.
 *
 * Test Class: QuoteSegmentFlagServiceTest
 */
public without sharing class QuoteSegmentFlagService {

    @TestVisible
    private static List<String> faultLog = new List<String>();

    // Test hook: replaces the QuoteLineGroup query.
    @TestVisible
    private static List<QuoteLineGroup> segmentOverride;

    public class Request {
        @InvocableVariable(label='Quote Id' required=true)
        public Id quoteId;

        @InvocableVariable(
            label='Excluded Segment Id'
            description='Segment about to be deleted; ignored when ranking'
        )
        public Id excludeGroupId;
    }

    @InvocableMethod(
        label='Flag Later Ramp Segments'
        description='Sets Is_Later_Segment__c on every segment of the quote that is not the first (earliest StartDate)'
        category='Revenue'
    )
    public static void run(List<Request> requests) {
        Map<Id, Set<Id>> excludedByQuote = new Map<Id, Set<Id>>();
        if (requests != null) {
            for (Request request : requests) {
                if (request == null || request.quoteId == null) {
                    continue;
                }
                if (!excludedByQuote.containsKey(request.quoteId)) {
                    excludedByQuote.put(request.quoteId, new Set<Id>());
                }
                if (request.excludeGroupId != null) {
                    excludedByQuote.get(request.quoteId).add(request.excludeGroupId);
                }
            }
        }
        flag(excludedByQuote);
    }

    // Backfill entry point: flag every group of these quotes.
    public static void flag(Set<Id> quoteIds) {
        Map<Id, Set<Id>> excludedByQuote = new Map<Id, Set<Id>>();
        if (quoteIds != null) {
            for (Id quoteId : quoteIds) {
                excludedByQuote.put(quoteId, new Set<Id>());
            }
        }
        flag(excludedByQuote);
    }

    public static void flag(Map<Id, Set<Id>> excludedByQuote) {
        try {
            applyFlags(excludedByQuote);
        } catch (Exception e) {
            faultLog.add('QuoteSegmentFlagService: ' + e.getMessage()
                + ' | ' + e.getStackTraceString());
        }
    }

    private static void applyFlags(Map<Id, Set<Id>> excludedByQuote) {
        if (excludedByQuote == null || excludedByQuote.isEmpty()) {
            return;
        }
        Set<Id> quoteIds = excludedByQuote.keySet();

        List<QuoteLineGroup> source = segmentOverride != null
            ? segmentOverride
            : [
                SELECT Id, QuoteId, StartDate, SortOrder, Is_Later_Segment__c
                FROM QuoteLineGroup
                WHERE QuoteId IN :quoteIds
            ];

        Map<Id, List<QuoteLineGroup>> byQuote = new Map<Id, List<QuoteLineGroup>>();
        for (QuoteLineGroup grp : source) {
            if (grp == null || grp.QuoteId == null || !quoteIds.contains(grp.QuoteId)) {
                continue;
            }
            if (excludedByQuote.get(grp.QuoteId).contains(grp.Id)) {
                continue;
            }
            if (!byQuote.containsKey(grp.QuoteId)) {
                byQuote.put(grp.QuoteId, new List<QuoteLineGroup>());
            }
            byQuote.get(grp.QuoteId).add(grp);
        }

        List<QuoteLineGroup> updates = new List<QuoteLineGroup>();
        for (Id quoteId : byQuote.keySet()) {
            List<QuoteLineGroup> groups = byQuote.get(quoteId);
            Map<Id, Boolean> later = evaluate(groups);
            for (QuoteLineGroup grp : groups) {
                Boolean shouldBeLater = later.get(grp.Id);
                if (shouldBeLater != null && grp.Is_Later_Segment__c != shouldBeLater) {
                    updates.add(new QuoteLineGroup(Id = grp.Id, Is_Later_Segment__c = shouldBeLater));
                }
            }
        }
        saveFlags(updates);
    }

    // Pure logic: group Id -> true when the group is NOT the first segment.
    @TestVisible
    private static Map<Id, Boolean> evaluate(List<QuoteLineGroup> groups) {
        Map<Id, Boolean> later = new Map<Id, Boolean>();
        if (groups == null) {
            return later;
        }
        QuoteLineGroup first = null;
        for (QuoteLineGroup grp : groups) {
            if (grp.StartDate != null && (first == null || precedes(grp, first))) {
                first = grp;
            }
        }
        for (QuoteLineGroup grp : groups) {
            later.put(grp.Id, first != null && grp.Id != first.Id);
        }
        return later;
    }

    // Earlier StartDate, then lower SortOrder (nulls last), then lower Id.
    private static Boolean precedes(QuoteLineGroup left, QuoteLineGroup right) {
        if (left.StartDate != right.StartDate) {
            return left.StartDate < right.StartDate;
        }
        if (left.SortOrder != right.SortOrder) {
            if (left.SortOrder == null) {
                return false;
            }
            if (right.SortOrder == null) {
                return true;
            }
            return left.SortOrder < right.SortOrder;
        }
        return String.valueOf(left.Id) < String.valueOf(right.Id);
    }

    private static void saveFlags(List<QuoteLineGroup> updates) {
        if (updates == null || updates.isEmpty()) {
            return;
        }
        List<Database.SaveResult> results = Database.update(updates, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                List<String> parts = new List<String>();
                for (Database.Error error : results[i].getErrors()) {
                    parts.add(error.getStatusCode() + ': ' + error.getMessage());
                }
                faultLog.add('QuoteLineGroup ' + updates[i].Id + ': ' + String.join(parts, ' | '));
            }
        }
    }
}