/**
 * Count of policyholders
 */
SELECT COUNT(*) FROM policyholder;

/**
 * Count of policies
 */
SELECT COUNT(*) FROM policy;

/**
 * Select all in-effect policies with monthly payment schedules
 */
SELECT *
FROM policy
WHERE `issued_timestamp` IS NOT NULL
    AND `cancellation_timestamp` IS NULL
    AND `payment_schedule_name` LIKE 'monthly'
    AND `policy_start_timestamp` < NOW()
    AND `policy_end_timestamp` > NOW();

/**
 * Select all policies issued with written premium within an interval
 */
SET @start_timestamp = unix_timestamp('2022-01-01') * 1000;
SET @end_timestamp = unix_timestamp('2022-07-01') * 1000;
SET @as_of_timestamp = unix_timestamp('2022-07-01') * 1000;

SELECT
pol.locator,
exp.name AS exp_name, exp.locator AS exp_locator,
per.name AS per_name, per.locator AS per_locator,
from_unixtime(MIN(per_c.start_timestamp/1000, '%Y-%m-%d')) AS effective_date,
from_unixtime(MAX(per_c.end_timestamp/1000, '%Y-%m-%d')) AS expiry_date,
SUM(per_c.premium) AS premium
FROM policy pol
JOIN exposure exp ON pol.locator = exp.policy_locator
JOIN peril per ON exp.locator = per.exposure_locator
JOIN peril_characteristics per_c ON per.locator = per_c.peril_locator
-- Policy is issued within the range provided
WHERE pol.issued_timestamp between @start_timestamp AND @end_timestamp
-- Keep all transactions created after the "as of" date before that date
AND per_c.created_timestamp <= @as_of_timestamp
-- Keep all transactions which have not been replaced before the "as of" date
AND (
    per_c.replaced_timestamp > @as_of_timestamp
    OR
    per_c.replaced_timestamp is null
)
GROUP BY exp_locator, exp_name, per_locator
ORDER BY pol.locator;

/**
 * Summarize specific set of field values with corresponding characteristics
 * and policy locators, across all policies
 */
SELECT
pc.policy_locator,
pc.start_timestamp,
pc.end_timestamp,
pcf.policy_characteristics_locator,
pcf.parent_locator,
-- Basic template for each field: MAX for aggregation requirement and null filter
MAX(CASE WHEN pcf.field_name = "driver_firstname" THEN pcf.field_value END) "driver_firstname",
MAX(CASE WHEN pcf.field_name = "driver_lastname" THEN pcf.field_value END) "driver_lastname",
MAX(CASE WHEN pcf.field_name = "driver_designation" THEN pcf.field_value END) "driver_designation"
FROM policy_characteristics_fields pcf
JOIN policy_characteristics pc ON pcf.policy_characteristics_locator = pc.locator
WHERE parent_name = "drivers"
GROUP BY pcf.policy_characteristics_locator, pcf.parent_locator
ORDER BY pcf.policy_characteristics_locator, pcf.parent_locator ASC;

/**
 * Categorized count of all modifications on a policy
 */
SET @policy_locator = 'locator-value';

SELECT pm.type as modification_type, COUNT(pm.type) as count
FROM policy_modification pm
WHERE pm.policy_locator = @policy_locator
GROUP BY pm.type;

/**
 * Fetch grace periods for a given policy
 */
SET @policy_locator = 'locator-value';

SELECT * FROM grace_period WHERE policy_locator = @policy_locator;

/**
 * Summarize financial transactions on invoices for a policy
 */
SET @policy_locator = 'locator-value';

SELECT tx.type, tx.amount,
    tx.peril_characteristics_locator, tx.invoice_locator,
    invoice.due_timestamp, invoice.settlement_status, invoice.settlement_type
FROM financial_transaction tx
JOIN invoice ON tx.invoice_locator = invoice.locator
WHERE tx.policy_locator = @policy_locator;

/**
 * Get invoices with unearned premium
 */
SET @asOfTimestamp = unix_timestamp('2022-01-01') * 1000;

SELECT
    inv.locator,
    inv.policy_locator
FROM invoice inv
JOIN policy p ON p.locator = inv.policy_locator
WHERE inv.created_timestamp <= @asOfTimestamp
ORDER BY inv.id ASC;

/**
 * Get premium financial transactions for an invoice
 */
SET @invoiceLocator = '';

SELECT
    ft.amount,
    p.currency,
    ft.start_timestamp,
    ft.end_timestamp,
    inv.due_timestamp,
    inv.created_timestamp
FROM invoice inv
JOIN financial_transaction ft ON ft.invoice_locator = inv.locator
JOIN policy p ON inv.policy_locator = p.locator
WHERE ft.type = 'premium'
  AND inv.locator = @invoiceLocator;

/**
 * Current policy status summary
 *   This example produces a simple table of [policy locator, current status]
 *   rows following simplified derivation logic seen in Core UI.
 *
 *   The idea is to collect all active grace periods for each policy, plus
 *   all of the "status-bearing" policy modifications that have effective
 *   timestamps <= now. From that mod set, for each policy, we pick the
 *   one mod with maximum effective timestamp AND issued timestamp, and then
 *   set the current status as follows:
 *     - Does this policy have an active grace period? Then 'in grace period'
 *     - Else, the status is mapped from the status-bearing policy mod
 */
SET @now = UNIX_TIMESTAMP() * 1000;
SELECT raw_data.policy_locator,
       CASE
           WHEN(raw_data.grace_locator IS NOT NULL)
                THEN 'in grace period'
                ELSE
                    CASE raw_data.mod_type
                        WHEN 'cancel' THEN 'cancelled'
                        WHEN 'create' THEN 'issued'
                        WHEN 'lapse' THEN 'lapsed'
                        WHEN 'reinstate' THEN 'reinstated'
                    END
       END AS current_status
FROM
(SELECT latest_status_mods.policy_locator,
       latest_status_mods.mod_type,
       active_graces.grace_locator
FROM
    (SELECT DISTINCT policy_locator,
                    FIRST_VALUE(type) OVER
                        (PARTITION BY policy_locator ORDER BY effective_timestamp DESC, issued_timestamp DESC) mod_type
        FROM policy_modification
        WHERE effective_timestamp <= @now
        AND type IN ('create', 'cancel', 'lapse', 'reinstate')) latest_status_mods
LEFT OUTER JOIN
    (SELECT gp.locator grace_locator, gp.policy_locator
     FROM
     grace_period gp
     WHERE
        gp.start_timestamp <= @now
        AND
        gp.end_timestamp >= @now
        AND
        gp.settled_timestamp IS NULL) active_graces
ON active_graces.policy_locator=latest_status_mods.policy_locator) raw_data;
