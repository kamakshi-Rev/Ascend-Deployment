# Deployment Log: Ascend_Deployement

| | |
|---|---|
| **Date** | 2026-10-29 |
| **Source org** | PilotOrg (`jdarla@teamascend.com.prod.pilot`). Retrieve only, no changes made |
| **Target org** | Ascend_Deployement (`ascend@deployment.com`, revsolutions-5d-dev-ed) |
| **Manifest** | [manifest/package.xml](manifest/package.xml) |
| **Deploy 1** (requested list) | `0AfdL00000ht3R7SAI`: succeeded, 333 / 333 components, 0 errors |
| **Deploy 2** (Product2 sync with Pilot) | `0AfdL00000hstZqSAI`: succeeded, 379 / 379 components, 0 errors |

## Summary

| Type | Count | Status |
|---|---|---|
| Custom objects | 4 | Deployed |
| Custom fields (requested list) | 318 | Deployed |
| Custom fields (added as dependencies) | 5 | Deployed |
| Product2 fields synced from Pilot | 46 | Deployed |
| Custom labels | 4 | Deployed |
| Global value sets (added as dependency) | 1 | Deployed |
| **Total in manifest** | **378** | |

The deploy counts are higher than the manifest total because they also count the parent object stub of each standard object and the CustomLabels container. The stubs are empty, so they did not change any object settings.

## Product2 comparison: Pilot vs Ascend_Deployement

Compared all Product2 custom fields with the Tooling API and a metadata retrieve from both orgs (read-only in Pilot).

| Result | Count | Action |
|---|---|---|
| In both orgs, definition identical | 9 | None |
| Active in Pilot, missing in Ascend | 46 | Retrieved from Pilot and deployed (deploy 2) |
| `*_del__c` in Pilot (deleted fields in the recycle bin) | 10 | Not retrievable; skipped |
| In Ascend but not in Pilot | 0 | None |

After deploy 2, Ascend_Deployement has 55 Product2 custom fields, matching the 55 active fields in Pilot. Skipped deleted fields: `ProductCode_Custom_del__c`, `SKU_BusinessUnit_del__c`, `SKU_Category_del__c`, `SKU_Company_del__c`, `SKU_LOB_del__c`, `SKU_Product_del__c`, `SKU_Sequence_del__c`, `SKU_Subproduct_del__c`, `Service_Category_del__c`, `Service_Sub_Category_del__c`.

Deploy 2 had no errors: none of the 46 fields use history tracking, global value sets or formulas. Its two lookups (`Primary_Vendor__c` to Account, `Service_Owner__c` to User) point to standard objects.

## Errors and resolution

The first dry run passed 322 of 327 components (errors 1 and 4–7). Errors 2–3 came up in the second dry run, after the Product2 fields were added. Every error below was fixed before the real deploy.

| # | Component | Error | Cause | Fix | Status |
|---|---|---|---|---|---|
| 1 | `At_Risk_Asset__c.Line_of_Business__c` | Field Service_Offering__c does not exist | Formula `TEXT(Asset__r.Product2.Service_Offering__c)` uses a Product2 field the target did not have | Added `Product2.Service_Offering__c` to the manifest | Solved |
| 2 | `Product2.Service_Family__c` (dependency) | Field Service_Offering__c does not exist | Formula `TEXT(Type__c) + " - " + TEXT(Service_Offering__c)` needs both fields | Added `Product2.Service_Offering__c` and `Product2.Type__c` | Solved |
| 3 | `Product2.Service_Offering__c` (dependency) | The global picklist cannot be resolved | Field uses global value set `Service_Offering`, which the target did not have | Added `GlobalValueSet:Service_Offering` | Solved |
| 4 | `Contract.Contract_Status__c` | Exceeded the allowed number of fields to track on a given entity | Field history tracking is on in Pilot; the target cannot track it | Set `trackHistory` to false in the local file | Solved, tracking off |
| 5 | `Contract.TCV__c` | The entity: Contract does not have feeds enabled | Feed tracking is on in Pilot; Contract feeds are off in the target | Set `trackFeedHistory` to false in the local file | Solved, tracking off |
| 6 | `Opportunity.Duration_in_Months__c` | Opportunity does not have history tracking enabled | Field history tracking is on in Pilot | Set `trackHistory` to false in the local file | Solved, tracking off |
| 7 | `Opportunity.Est_Start_Date__c` | Opportunity does not have history tracking enabled | Field history tracking is on in Pilot | Set `trackHistory` to false in the local file | Solved, tracking off |

Final dry run: 333 / 333 succeeded. Final deploy: 333 / 333 succeeded.

## Differences from Pilot

These 4 fields are deployed **without** the history or feed tracking they have in Pilot. To match Pilot, turn tracking on in Setup → Object Manager → *object* → Fields & Relationships → Set History Tracking, or enable Feed Tracking.

- `Contract.Contract_Status__c`
- `Contract.TCV__c`
- `Opportunity.Duration_in_Months__c`
- `Opportunity.Est_Start_Date__c`

## Open items after deployment

| # | Item | Status |
|---|---|---|
| 1 | **Field-level security.** The new fields have no FLS for `ascend@deployment.com` (checked via describe of Product2), so they do not show on pages or in Inspector Data Import. Grant access with a permission set (for example `Revenue_Cloud_Field_Level_Access_PS`) | Open |
| 2 | **Custom label `Churn_Case_Record_Type_Id`.** Set its value to the Churn_Cases record type Id in this org | Open |
| 3 | **`ApprovalWorkItem.Approval_Work_Item_Name__c`.** The formula hard-codes the Pilot URL; edit it for this org | Open |
| 4 | **History and feed tracking** on the 4 fields above, if needed | Open |

## Deployed components

### Custom objects (4)

- `Account_Margin_History__c`
- `At_Risk_Asset__c`
- `Case_Asset__c`
- `Term_Discount__c`

### Custom labels (4)

- `Churn_Case_Record_Type_Id`
- `Level_1_EC_CO_RN_Approver`
- `Level_1_New_Logo_Approver`
- `Level_2_Approver`

### Global value sets (1)

- `Service_Offering` (dependency of `Product2.Service_Offering__c`)

### Custom fields (369)

Marks: **(dep)** = added as a dependency, not in the original list. **(sync)** = added by the Product2 comparison with Pilot. **(no tracking)** = tracking turned off, see above.

<details><summary><b>Account</b> (8)</summary>

- `Account_Abbreviation_2__c`
- `Account_Executive__c`
- `Cybersecurity_Margin__c`
- `Infrastructure_Margin__c`
- `Onboarding_Margin__c`
- `Private_Cloud_Margin__c`
- `Service_Desk_Margin__c`
- `VOIP_Margin__c`

</details>

<details><summary><b>Account_Margin_History__c</b> (9)</summary>

- `Account__c`
- `Effective_Month__c`
- `Margin_Cyber__c`
- `Margin_Desk__c`
- `Margin_Infra__c`
- `Margin_Onboarding__c`
- `Margin_Private_Cloud__c`
- `Margin_Total__c`
- `Margin_VOIP__c`

</details>

<details><summary><b>ApprovalWorkItem</b> (2)</summary>

- `Approval_Condition_Name__c`
- `Approval_Work_Item_Name__c`

</details>

<details><summary><b>Asset</b> (4)</summary>

- `AssetExtId__c`
- `Status`
- `XAsset_Lifecycle_Start_Date__c`
- `XRenewal_Initiated__c`

</details>

<details><summary><b>AssetAction</b> (1)</summary>

- `Line_of_Business__c`

</details>

<details><summary><b>AssetActionSource</b> (1)</summary>

- `ConstraintEngineNodeStatus__c`

</details>

<details><summary><b>AssetStatePeriod</b> (2)</summary>

- `Category__c`
- `Line_of_Business__c`

</details>

<details><summary><b>At_Risk_Asset__c</b> (8)</summary>

- `Annualized_At_Risk_Revenue__c`
- `Asset__c`
- `Case__c`
- `Current_MRR__c`
- `Current_Quantity__c`
- `Line_of_Business__c`
- `Term__c`
- `Total_Lifecycle_Amount__c`

</details>

<details><summary><b>Case</b> (17)</summary>

- `Annualized_At_Risk_Revenue__c`
- `Churn_Notice__c`
- `Close_Date__c`
- `Contract_End_Date__c`
- `Contract__c`
- `Est_Start_Date__c`
- `Gross_Margin__c`
- `LOB_Rollup__c`
- `Next_Step__c`
- `Offboarding_Date__c`
- `Probability__c`
- `TCV__c`
- `Termination_Category__c`
- `Termination_Fee__c`
- `Termination_Reason__c`
- `Termination_Terms__c`
- `Termination_Type__c`

</details>

<details><summary><b>Case_Asset__c</b> (2)</summary>

- `Asset__c`
- `Case__c`

</details>

<details><summary><b>Contract</b> (53)</summary>

- `Annual_Increase__c`
- `At_Risk_Case__c`
- `At_Risk_Status__c`
- `Auto_Renew_Increase__c`
- `Auto_Renew__c`
- `Billing_Type__c`
- `Booked_MRR__c`
- `ContractExtId__c`
- `Contract_At_Risk_Status__c`
- `Contract_Status__c` **(no tracking)**
- `Contract_Version__c`
- `Current_MRR_Cyber__c`
- `Current_MRR_Desk__c`
- `Current_MRR_Infra__c`
- `Current_MRR_Private_Cloud__c`
- `Current_MRR_VOIP__c`
- `Current_MRR__c`
- `Current_TCV__c`
- `Discount__c`
- `Existing_MRR_Cyber__c`
- `Existing_MRR_Desk__c`
- `Existing_MRR_Infra__c`
- `Existing_MRR_Private_Cloud__c`
- `Existing_MRR_VOIP__c`
- `Existing_MRR__c`
- `Existing_TCV__c`
- `Integration_Status__c`
- `Last_Stamped_Order__c`
- `Margin_Total__c`
- `Month_to_Month__c`
- `Original_End_Date__c`
- `Owner_Expiration_Notice__c`
- `Previous_MRR_Cyber__c`
- `Previous_MRR_Desk__c`
- `Previous_MRR_Infra__c`
- `Previous_MRR_Private_Cloud__c`
- `Previous_MRR_VOIP__c`
- `Previous_MRR__c`
- `Previous_TCV__c`
- `Ready_For_Renewal_Creation__c`
- `Referral_Fee__c`
- `Renewal_Initiated__c`
- `Renewal_Override__c`
- `SOW__c`
- `Sold_Gross_Margin_Cyber__c`
- `Sold_Gross_Margin_Desk__c`
- `Sold_Gross_Margin_Infra__c`
- `Sold_Gross_Margin_Onboarding__c`
- `Sold_Gross_Margin_Private_Cloud__c`
- `Sold_Gross_Margin_Total__c`
- `Sold_Gross_Margin_VOIP__c`
- `TCV__c` **(no tracking)**
- `Uplift_Percent__c`

</details>

<details><summary><b>Opportunity</b> (32)</summary>

- `Booked_MRR__c`
- `Duration_in_Months__c` **(no tracking)**
- `Est_Start_Date__c` **(no tracking)**
- `Loss_MRR__c`
- `Loss_Type__c`
- `MRR_Change_Cyber__c`
- `MRR_Change_Desk__c`
- `MRR_Change_Infra__c`
- `MRR_Change_Private_Cloud__c`
- `MRR_Change_VOIP__c`
- `Margin_Cyber__c`
- `Margin_Desk__c`
- `Margin_Infra__c`
- `Margin_Onboarding__c`
- `Margin_Private_Cloud__c`
- `Margin_VOIP__c`
- `Net_Booked_MRR_Cyber__c`
- `Net_Booked_MRR_Desk__c`
- `Net_Booked_MRR_Infra__c`
- `Net_Booked_MRR_Private_Cloud__c`
- `Net_Booked_MRR_Total__c`
- `Net_Booked_MRR_VOIP__c`
- `Net_TCV_Total__c`
- `Number_of_Quotes__c`
- `Opportunity_Description__c`
- `Previous_MRR__c`
- `Previous_TCV__c`
- `Renewal_MRR_Rollup__c`
- `Renewal_MRR__c`
- `Renewal_TCV_Rollup__c`
- `Renewal_TCV__c`
- `Sold_Gross_Margin__c`

</details>

<details><summary><b>Order</b> (18)</summary>

- `Amortized_Term_Months__c`
- `Auto_Renew_Increase__c`
- `Contract_Term_Months__c`
- `Cybersecurity_Principal_Amount__c`
- `Cybersecurity_Principal_Monthly__c`
- `Infrastructure_Principal_Amount__c`
- `Infrastructure_Principal_Monthly__c`
- `Managed_Security_Licensing_Total__c`
- `Managed_Security_Service_Total__c`
- `Monitoring_Licensing_Total__c`
- `Monitoring_Service_Total__c`
- `Onboarding_Fee_Amortized__c`
- `Principal_Bundle_MRR__c`
- `Principal_Bundle_Monthly__c`
- `Private_Cloud_Principal_Amount__c`
- `Private_Cloud_Principal_Monthly__c`
- `Service_Desk_Principal_Amount__c`
- `Service_Desk_Principal_Monthly__c`

</details>

<details><summary><b>OrderItem</b> (8)</summary>

- `Category__c`
- `ConstraintEngineNodeStatus__c`
- `Custom_Uplift_Price_Amount__c`
- `Custom_Uplift_Price_Percentage__c`
- `Is_Part_Of_Bundle__c`
- `Line_of_Business__c`
- `MRR__c`
- `Net_Unit_Price_After_System_Discounts__c`

</details>

<details><summary><b>Product2</b> (55)</summary>

- `Auto_Renew_Eligible__c` **(sync)**
- `BRD_URL__c` **(sync)**
- `Billing_Frequency__c` **(sync)**
- `Billing_Type__c` **(sync)**
- `Category__c` **(dep)**
- `Default_Quantity__c` **(sync)**
- `Delivery_Team__c` **(sync)**
- `Eligible_for_Volume_Discount__c` **(sync)**
- `Est_Delivery_Hours__c` **(sync)**
- `Exclude_from_Volume_Discount__c` **(sync)**
- `External_Id__c` **(sync)**
- `FRD_URL__c` **(sync)**
- `GL_Account_Deferred__c` **(sync)**
- `GL_Account_Hard_Cost__c` **(sync)**
- `GL_Account_Labor_Cost__c` **(sync)**
- `GL_Account_Revenue__c` **(sync)**
- `Hard_Cost_COGS__c` **(sync)**
- `Intacct_Dimension_SL__c` **(sync)**
- `Intacct_Item_ID__c` **(sync)**
- `Internal_Notes__c` **(sync)**
- `Is_Managed_Security_SKU__c`
- `Is_Monitoring_SKU__c`
- `Labor_Cost_COGS__c` **(sync)**
- `Last_Review_Date__c` **(sync)**
- `Legacy_Record_Id__c` **(sync)**
- `Lifecycle_Notes__c` **(sync)**
- `Marketing_Name__c` **(sync)**
- `Min_Commitment_Months__c` **(sync)**
- `Minimum_Dollar_Enforced__c` **(sync)**
- `PRD_URL__c` **(sync)**
- `Pricing_Model__c` **(sync)**
- `Primary_Vendor__c` **(sync)**
- `Rev_Rec_Method__c` **(sync)**
- `SLA_Tier__c` **(sync)**
- `SNOW_SF_Service_Name__c` **(sync)**
- `SNOW_Service_Name__c` **(sync)**
- `SN_Assignment_Group__c` **(sync)**
- `SN_Category__c` **(sync)**
- `SN_SubCategory__c` **(sync)**
- `ServiceNow_Rate_Card_ID__c` **(sync)**
- `Service_Assumptions__c` **(sync)**
- `Service_Client_Responsibilities__c` **(sync)**
- `Service_Family__c` **(dep)**
- `Service_Offering__c` **(dep)**
- `Service_Owner__c` **(sync)**
- `Service_Package__c` **(dep)**
- `Service_Reporting__c` **(sync)**
- `Service_Tier__c`
- `Status__c`
- `Type__c` **(dep)**
- `Vendor_Billing_Frequency__c` **(sync)**
- `Vendor_Contract_Ref__c` **(sync)**
- `Vendor_SKU__c` **(sync)**
- `Vendor_Unit_Cost__c` **(sync)**
- `Version__c` **(sync)**

</details>

<details><summary><b>ProductDisqualification</b> (1)</summary>

- `OriginalActionType__c`

</details>

<details><summary><b>ProductQualification</b> (3)</summary>

- `End_Of_Life_Date__c`
- `OriginalActionType__c`
- `Product_Lifecycle_Status__c`

</details>

<details><summary><b>Quote</b> (112)</summary>

- `Amortized_Term_Months__c`
- `Annual_Increase__c`
- `Annualized_At_Risk_Revenue__c`
- `Approval_Scenario__c`
- `Approved_Date__c`
- `Ascend_Legacy_Quote_ID__c`
- `Auto_Renew_Increase__c`
- `Booked_MRR__c`
- `Contract_Term_Months__c`
- `Contract_Version__c`
- `Current_MRR_Cyber__c`
- `Current_MRR_Desk__c`
- `Current_MRR_Infra__c`
- `Current_MRR_Private_Cloud__c`
- `Current_MRR_VOIP__c`
- `Current_MRR__c`
- `Current_TCV__c`
- `Cybersecurity_Est_Monthly_Effort__c`
- `Cybersecurity_Principal_Amount__c`
- `Cybersecurity_Principal_Monthly__c`
- `Est_Hours_Cyber__c`
- `Est_Hours_Desk__c`
- `Est_Hours_Infra__c`
- `Est_Hours_Private_Cloud__c`
- `Est_Hours_VOIP__c`
- `Existing_MRR_Cyber__c`
- `Existing_MRR_Desk__c`
- `Existing_MRR_Infra__c`
- `Existing_MRR_Private_Cloud__c`
- `Existing_MRR_VOIP__c`
- `Existing_MRR__c`
- `Existing_TCV__c`
- `Financial_Metrics_In_Sync__c`
- `GRR__c`
- `Infrastructure_Est_Monthly_Effort__c`
- `Infrastructure_Principal_Amount__c`
- `Infrastructure_Principal_Monthly__c`
- `Loss_MRR_Cyber__c`
- `Loss_MRR_Desk__c`
- `Loss_MRR_Infra__c`
- `Loss_MRR_Private_Cloud__c`
- `Loss_MRR_VOIP__c`
- `MRR_Change_Cyber__c`
- `MRR_Change_Desk__c`
- `MRR_Change_Infra__c`
- `MRR_Change_Pct_Cyber__c`
- `MRR_Change_Pct_Desk__c`
- `MRR_Change_Pct_Infra__c`
- `MRR_Change_Pct_Private_Cloud__c`
- `MRR_Change_Pct_VOIP__c`
- `MRR_Change_Private_Cloud__c`
- `MRR_Change_VOIP__c`
- `Managed_Security_Licensing_Total__c`
- `Managed_Security_Service_Total__c`
- `Margin_Cyber__c`
- `Margin_Desk__c`
- `Margin_Infra__c`
- `Margin_Onboarding__c`
- `Margin_Private_Cloud__c`
- `Margin_Total__c`
- `Margin_VOIP__c`
- `Monitoring_Licensing_Total__c`
- `Monitoring_Service_Total__c`
- `Month_to_Month__c`
- `NRR__c`
- `Net_Booked_MRR_Cyber__c`
- `Net_Booked_MRR_Desk__c`
- `Net_Booked_MRR_Infra__c`
- `Net_Booked_MRR_Private_Cloud__c`
- `Net_Booked_MRR_Total__c`
- `Net_Booked_MRR_VOIP__c`
- `Net_Less_Than_Existing__c`
- `Net_MRR_Cyber__c`
- `Net_MRR_Desk__c`
- `Net_MRR_Infra__c`
- `Net_MRR_Private_Cloud__c`
- `Net_MRR_VOIP__c`
- `Net_MRR__c`
- `Net_TCV_Total__c`
- `Net_TCV__c`
- `Number_of_Users__c`
- `Onboarding_Fee_Amortized__c`
- `Onboarding_Fee_Waived__c`
- `OriginalActionType__c`
- `Per_User_Price__c`
- `Previous_Booked_MRR__c`
- `Previous_TCV__c`
- `Principal_Bundle_MRR__c`
- `Principal_Bundle_Monthly__c`
- `Private_Cloud_Est_Monthly_Effort__c`
- `Private_Cloud_Principal_Amount__c`
- `Private_Cloud_Principal_Monthly__c`
- `Ramp_Start_Date_Mismatch__c`
- `Service_Desk_Est_Monthly_Effort__c`
- `Service_Desk_Principal_Amount__c`
- `Service_Desk_Principal_Monthly__c`
- `Status`
- `Term_Change_Requested__c`
- `Total_Deal_Margin__c`
- `VOIP_Est_Monthly_Effort__c`
- `XCybersecurity_Margin__c`
- `XExisting_SD_Line_Count__c`
- `XHas_ServiceDesk_Services__c`
- `XInfrastructure_Margin__c`
- `XMS_Product_Discount_Requires_Executive__c`
- `XManaged_Security_Awareness_Program_Fee__c`
- `XMonitoring_Fee__c`
- `XOnboarding_Margin__c`
- `XPrivate_Cloud_Margin__c`
- `XQuote_Name__c`
- `XService_Desk_Margin__c`
- `XVOIP_Margin__c`

</details>

<details><summary><b>QuoteLineItem</b> (27)</summary>

- `Adjustment_Per_SKU__c`
- `Base_Price__c`
- `Bundle_Margin_Percent__c`
- `Bundle_Parent_Quantiy__c`
- `Bundle_Price_Display__c`
- `Bundle_Revenue__c`
- `Category__c`
- `ConstraintEngineNodeStatus__c`
- `Custom_Uplift_Price_Amount__c`
- `Custom_Uplift_Price_Percentage__c`
- `Entitlement_Quantity__c`
- `HaaS_Hardware_Amount__c`
- `HaaS_Hardware_Description__c`
- `Is_Bundle_Parent__c`
- `Is_Part_Of_Bundle__c`
- `Line_of_Business__c`
- `MRR__c`
- `MSRP_Total__c`
- `Net_Unit_Price_After_System_Discounts__c`
- `Original_Quantity__c`
- `Product_Description__c`
- `Revenue_Bundle__c`
- `Total_Per_User_Per_SKU__c`
- `Unit_Of_Measure__c`
- `XCost_Price__c`
- `XEstimated_Expense_Price__c`
- `XItem_Action_Status__c`

</details>

<details><summary><b>Term_Discount__c</b> (6)</summary>

- `Discount__c`
- `Lower_Bound__c`
- `Product_Selling_Model__c`
- `Product__c`
- `Tier_Type__c`
- `Upper_Bound__c`

</details>

## How to re-run

```bash
# Retrieve from Pilot (read-only)
sf project retrieve start -x manifest/package.xml -o PilotOrg
# Validate without saving
sf project deploy start --dry-run -x manifest/package.xml -o Ascend_Deployement
# Deploy
sf project deploy start -x manifest/package.xml -o Ascend_Deployement
```

A fresh retrieve brings the tracking settings back from Pilot. Re-apply the 4 tracking edits before deploying.