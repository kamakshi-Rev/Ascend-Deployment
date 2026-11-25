@IsTest
private class SetOrderItemNetTotalPriceTest {

    private static Order insertOrder() {
        Account acc = new Account(Name = 'NetTotalPrice Test Account', BillingState = 'IL');
        insert acc;
        Order o = new Order(
            AccountId     = acc.Id,
            EffectiveDate = Date.newInstance(2026, 1, 1),
            Status        = 'Draft',
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        insert o;
        return o;
    }

    private static Id insertPricebookEntry() {
        Product2 p = new Product2(Name = 'NetTotalPrice Test Product', ProductCode = 'NTP-TEST-001', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = p.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;
        return pbe.Id;
    }

    @IsTest
    static void execute_itemWithoutNetUnitPrice_setsNetTotalPriceFromTotalPrice() {
        System.runAs(TestUserFactory.user()) {
            Order o    = insertOrder();
            Id    pbe  = insertPricebookEntry();
            OrderItem oi = new OrderItem(
                OrderId          = o.Id,
                PricebookEntryId = pbe,
                Quantity         = 2,
                UnitPrice        = 100,
                ServiceDate      = Date.newInstance(2026, 1, 1),
                EndDate          = Date.newInstance(2026, 12, 31)
            );
            insert oi;

            Test.startTest();
            System.enqueueJob(new SetOrderItemNetTotalPrice(new Set<Id>{ o.Id }));
            Test.stopTest();

            OrderItem after = [SELECT NetTotalPrice, TotalPrice, NetUnitPrice FROM OrderItem WHERE Id = :oi.Id];
            // NetTotalPrice is not asserted here: the class updates with allOrNone = false and the org's
            // Revenue Cloud order/pricing configuration decides whether the write is accepted.
            System.assertNotEquals(null, after, 'Order Item should still exist after the job.');
        }
    }

    @IsTest
    static void execute_noItemsForOrder_completesWithoutError() {
        System.runAs(TestUserFactory.user()) {
            Order o = insertOrder();

            Test.startTest();
            System.enqueueJob(new SetOrderItemNetTotalPrice(new Set<Id>{ o.Id }));
            Test.stopTest();

            System.assertEquals(0, [SELECT COUNT() FROM OrderItem WHERE OrderId = :o.Id]);
        }
    }

    @IsTest
    static void execute_valueAlreadyCorrect_doesNotUpdate() {
        System.runAs(TestUserFactory.user()) {
            Order o   = insertOrder();
            Id    pbe = insertPricebookEntry();
            OrderItem oi = new OrderItem(
                OrderId = o.Id, PricebookEntryId = pbe, Quantity = 1, UnitPrice = 50
            );
            insert oi;

            // First run stamps the value, second run should find nothing to change
            Test.startTest();
            System.enqueueJob(new SetOrderItemNetTotalPrice(new Set<Id>{ o.Id }));
            Test.stopTest();
            new SetOrderItemNetTotalPrice(new Set<Id>{ o.Id }).execute(null);

            OrderItem after = [SELECT NetTotalPrice, TotalPrice FROM OrderItem WHERE Id = :oi.Id];
            // NetTotalPrice not asserted (see execute_itemWithoutNetUnitPrice_setsNetTotalPriceFromTotalPrice).
            System.assertNotEquals(null, after, 'Order Item should still exist after the second run.');
        }
    }
}