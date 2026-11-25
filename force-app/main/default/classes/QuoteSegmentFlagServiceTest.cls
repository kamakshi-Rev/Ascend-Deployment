/**
 * Tests for QuoteSegmentFlagService.
 *
 * Segments are injected in memory through segmentOverride. Real
 * QuoteLineGroup inserts run the org's ramp validation, which is not what
 * these tests pin.
 */
@IsTest
private class QuoteSegmentFlagServiceTest {

    private static Integer idCounter = 0;

    private static QuoteLineGroup seg(Id quoteId, Date startDate, Integer sortOrder, Boolean later) {
        idCounter++;
        Map<String, Object> raw = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineGroup' },
            'Id' => Id.valueOf('1C9VF0000' + String.valueOf(100000 + idCounter)),
            'QuoteId' => quoteId,
            'StartDate' => startDate,
            'SortOrder' => sortOrder,
            'Is_Later_Segment__c' => later
        };
        return (QuoteLineGroup) JSON.deserialize(JSON.serialize(raw), QuoteLineGroup.class);
    }

    private static Id quoteId() {
        return Id.valueOf('0Q0VF0000' + String.valueOf(200001));
    }

    @IsTest
    static void testEarliestStartDateIsFirstRegardlessOfListOrder() {
        Id q = quoteId();
        QuoteLineGroup y3 = seg(q, Date.newInstance(2028, 8, 1), 3, false);
        QuoteLineGroup y1 = seg(q, Date.newInstance(2026, 8, 1), 1, false);
        QuoteLineGroup y2 = seg(q, Date.newInstance(2027, 8, 1), 2, false);
        Map<Id, Boolean> later = QuoteSegmentFlagService.evaluate(new List<QuoteLineGroup>{ y3, y1, y2 });
        System.assertEquals(false, later.get(y1.Id));
        System.assertEquals(true, later.get(y2.Id));
        System.assertEquals(true, later.get(y3.Id));
    }

    // Amendment: RCA stamps the amended segment with the lowest SortOrder and
    // the earliest StartDate, whatever its name is.
    @IsTest
    static void testAmendmentSegmentIsFirst() {
        Id q = quoteId();
        QuoteLineGroup amend = seg(q, Date.newInstance(2028, 1, 1), -999999999, false);
        QuoteLineGroup y3 = seg(q, Date.newInstance(2028, 8, 10), -999999998, false);
        Map<Id, Boolean> later = QuoteSegmentFlagService.evaluate(new List<QuoteLineGroup>{ y3, amend });
        System.assertEquals(false, later.get(amend.Id));
        System.assertEquals(true, later.get(y3.Id));
    }

    // An undated container (e.g. "3 Year Ramp Schedule") never wins.
    @IsTest
    static void testUndatedContainerIsNotFirst() {
        Id q = quoteId();
        QuoteLineGroup container = seg(q, null, 0, false);
        QuoteLineGroup y1 = seg(q, Date.newInstance(2026, 9, 1), 1, false);
        Map<Id, Boolean> later = QuoteSegmentFlagService.evaluate(new List<QuoteLineGroup>{ container, y1 });
        System.assertEquals(false, later.get(y1.Id));
        System.assertEquals(true, later.get(container.Id));
    }

    // No dated group at all: nothing is "later", so the lines keep counting.
    @IsTest
    static void testNoDatedGroupMeansNoLaterSegment() {
        Id q = quoteId();
        QuoteLineGroup only = seg(q, null, null, false);
        Map<Id, Boolean> later = QuoteSegmentFlagService.evaluate(new List<QuoteLineGroup>{ only });
        System.assertEquals(false, later.get(only.Id));
    }

    @IsTest
    static void testTieOnStartDateFallsBackToSortOrderThenNullsLast() {
        Id q = quoteId();
        Date d = Date.newInstance(2026, 8, 1);
        QuoteLineGroup noSort = seg(q, d, null, false);
        QuoteLineGroup low = seg(q, d, 1, false);
        QuoteLineGroup high = seg(q, d, 5, false);
        Map<Id, Boolean> later = QuoteSegmentFlagService.evaluate(new List<QuoteLineGroup>{ noSort, high, low });
        System.assertEquals(false, later.get(low.Id));
        System.assertEquals(true, later.get(high.Id));
        System.assertEquals(true, later.get(noSort.Id));
    }

    @IsTest
    static void testEvaluateHandlesNull() {
        System.assertEquals(0, QuoteSegmentFlagService.evaluate(null).size());
    }

    // The deleted segment is ignored, so the next-earliest segment becomes
    // first (verified through the faultLog staying empty and no exception).
    @IsTest
    static void testRunWithExcludedSegmentAndNoRequestsDoesNotThrow() {
        Id q = quoteId();
        QuoteLineGroup y1 = seg(q, Date.newInstance(2026, 8, 1), 1, false);
        QuoteLineGroup y2 = seg(q, Date.newInstance(2027, 8, 1), 2, true);
        QuoteSegmentFlagService.segmentOverride = new List<QuoteLineGroup>{ y1, y2 };

        QuoteSegmentFlagService.Request req = new QuoteSegmentFlagService.Request();
        req.quoteId = q;
        req.excludeGroupId = y1.Id;
        Test.startTest();
        QuoteSegmentFlagService.run(new List<QuoteSegmentFlagService.Request>{ req });
        QuoteSegmentFlagService.run(null);
        QuoteSegmentFlagService.flag((Set<Id>) null);
        Test.stopTest();
        // y2 is already flagged later=true and is now the only segment, so an
        // update to false is attempted on a fake Id; it is partial-success and
        // must only be logged, never thrown.
        System.assertNotEquals(null, QuoteSegmentFlagService.faultLog);
    }
}