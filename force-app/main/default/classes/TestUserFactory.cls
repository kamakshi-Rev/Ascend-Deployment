/**
 * Test-only helper that returns the user the Revenue Cloud test classes run as.
 *
 * Why: during a deployment validation the release's fields and permission sets
 * exist only inside the deployment transaction, so the deploying user has no
 * field access on them. Revenue Cloud's save path for Quote / QuoteLineItem /
 * OrderItem honours the running user's field access, so plain test DML fails
 * with "fields being inaccessible" / "No such column". Assigning the release's
 * permission sets to the running user inside the test, then running the test
 * body in System.runAs(that user), makes the new access take effect.
 *
 * Licences are NOT assigned here: permission set licence assignments made
 * inside a test are not honoured by Revenue Cloud's licence checks (licence-gated
 * standard fields such as QuoteLineItem.TotalCost / OrderItem.NetUnitPrice stay
 * hidden and "place sales transaction service" is refused). The deploying user
 * must already hold the Revenue Cloud licences in the target org
 * (runbook §3.1): Revenue Cloud User, Salesforce Pricing Run Time / Design Time,
 * Product Discovery User, Product Configuration User, Context Service Admin,
 * Product Catalog Management Administrator, Business Rules Engine Runtime,
 * Contract LifeCycle Management User.
 *
 * Usage (inside a test method):
 *     System.runAs(TestUserFactory.user()) { ... test body ... }
 */
@IsTest
public class TestUserFactory {

    private static User cached;

    /** Permission sets in this release (plus the two pilot bypass sets, if present). */
    private static final List<String> PERMISSION_SETS = new List<String>{
        'Rev_Cloud_Standard_Field_Access',
        'Rev_Cloud_Object_and_License',
        'Rev_Cloud_General_Purpose_Permissions',
        'Revenue_Cloud_Field_Level_Access_PS',
        'Financial_Metrics_Field_Access',
        'Churn_Case_Process',
        'Quote_Term_Validation_Bypass_Access',
        'Contract_MonthToMonth_Edit'
    };

    /**
     * Returns the running (deploying) user with the release's permission sets
     * assigned. The assignment is done once per test method (statics reset per
     * method) inside System.runAs(current user) so that the data DML that
     * follows inside System.runAs(user) is not mixed DML. Permission sets the
     * user already holds, or that don't exist in the org, are skipped.
     */
    public static User user() {
        if (cached != null) return cached;

        User me = new User(Id = UserInfo.getUserId());
        System.runAs(me) {
            Set<Id> already = new Set<Id>();
            for (PermissionSetAssignment psa : [
                SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :me.Id
            ]) {
                already.add(psa.PermissionSetId);
            }

            List<PermissionSetAssignment> psAssigns = new List<PermissionSetAssignment>();
            for (PermissionSet ps : [
                SELECT Id FROM PermissionSet
                WHERE Name IN :PERMISSION_SETS AND IsOwnedByProfile = false
            ]) {
                if (!already.contains(ps.Id)) {
                    psAssigns.add(new PermissionSetAssignment(AssigneeId = me.Id, PermissionSetId = ps.Id));
                }
            }
            if (!psAssigns.isEmpty()) Database.insert(psAssigns, false);
        }
        cached = me;
        return cached;
    }
}