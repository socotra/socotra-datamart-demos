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
 * Raw "on-risk" report, with field values at various levels aggregated
 * into a JSON representation for post-fetch-processing
 */
SET time_zone = '-07:00';
SET @asOfTimestamp = unix_timestamp('2022-11-22') * 1000;
SET @productName = 'personal-auto';

SELECT policy.product_name AS product_name,
       policy.locator AS policy_id,
       policy.payment_schedule_name AS payment_schedule_name,
       exposure.locator AS exposure_locator,
       exposure.name AS exposure_name,
       peril.locator AS peril_locator,
       peril.name AS peril_name,
       FROM_UNIXTIME(peril_characteristics.issued_timestamp / 1000, '%Y%m%d') AS issued_date,
       peril_characteristics.premium AS premium,
       FROM_UNIXTIME(peril_characteristics.start_timestamp / 1000, '%Y%m%d') AS coverage_start,
       FROM_UNIXTIME(peril_characteristics.end_timestamp / 1000, '%Y%m%d') AS coverage_end,
       policy_characteristics.locator AS policy_characteristics_locator,
       exposure_characteristics.locator AS exposure_characteristics_locator,
        (SELECT JSON_ARRAYAGG(JSON_OBJECT('parent_name', coalesce(parent_name,''), 'parent_locator', coalesce(parent_locator, ''),'field_name', field_name,'id', id, 'field_value', field_value)) FROM policy_characteristics_fields pchf
         WHERE is_group = false AND pchf.policy_characteristics_locator = peril_characteristics.policy_characteristics_locator) AS policy_fields,
        (SELECT JSON_ARRAYAGG(JSON_OBJECT('parent_name', coalesce(parent_name,''), 'parent_locator', coalesce(parent_locator, ''),'field_name', field_name,'id', id, 'field_value', field_value)) FROM exposure_characteristics_fields echf
         WHERE is_group = false AND echf.exposure_characteristics_locator = peril_characteristics.exposure_characteristics_locator) AS exposure_fields,
        (SELECT JSON_ARRAYAGG(JSON_OBJECT('parent_name', coalesce(parent_name,''), 'parent_locator', coalesce(parent_locator, ''),'field_name', field_name,'id', id, 'field_value', field_value)) FROM peril_characteristics_fields pchf
         WHERE is_group = false AND pchf.peril_characteristics_locator = peril_characteristics.locator) AS peril_fields
FROM peril_characteristics
JOIN peril ON peril_characteristics.peril_locator = peril.locator
JOIN exposure_characteristics ON peril_characteristics.exposure_characteristics_locator = exposure_characteristics.locator
JOIN policy_characteristics ON peril_characteristics.policy_characteristics_locator = policy_characteristics.locator
JOIN exposure ON exposure_characteristics.exposure_locator = exposure.locator
JOIN policy ON peril_characteristics.policy_locator = policy.locator
WHERE
    policy.product_name = @productName
    AND peril_characteristics.start_timestamp <= @asOfTimestamp
    AND peril_characteristics.end_timestamp > @asOfTimestamp
    AND peril_characteristics.replaced_timestamp IS NULL
    AND exposure_characteristics.start_timestamp <= @asOfTimestamp
    AND exposure_characteristics.end_timestamp > @asOfTimestamp
    AND exposure_characteristics.replaced_timestamp IS NULL
    AND policy_characteristics.start_timestamp <= @asOfTimestamp
    AND policy_characteristics.end_timestamp > @asOfTimestamp
    AND policy_characteristics.replaced_timestamp IS NULL
ORDER BY policy_id;

/**
 * Raw "all policies" report, with field values at various levels aggregated
 * into a JSON representation for post-fetch-processing
 */
SET @startTimestamp = unix_timestamp('2022-11-22') * 1000;
SET @endTimestamp = unix_timestamp('2022-12-22') * 1000;
SET @productName = 'personal-auto';

SELECT policy.product_name AS product_name,
       policy.locator AS policy_id,
       policy.payment_schedule_name AS payment_schedule_name,
       exposure.locator AS exposure_locator,
       exposure.name AS exposure_name,
       peril.locator AS peril_locator,
       peril.name AS peril_name,
       FROM_UNIXTIME(peril_characteristics.issued_timestamp / 1000, '%Y%m%d') AS issued_date,
       peril_characteristics.premium AS premium,
       FROM_UNIXTIME(peril_characteristics.start_timestamp / 1000, '%Y%m%d') AS coverage_start,
       FROM_UNIXTIME(peril_characteristics.end_timestamp / 1000, '%Y%m%d') AS coverage_end,
       pm.name AS modification_name,
        (SELECT JSON_ARRAYAGG(JSON_OBJECT('parent_name', coalesce(parent_name,''), 'parent_locator', coalesce(parent_locator, ''),'field_name', field_name,'id', id, 'field_value', field_value)) FROM policy_characteristics_fields pchf
         WHERE is_group = false AND pchf.policy_characteristics_locator = peril_characteristics.policy_characteristics_locator) AS policy_fields,
        (SELECT JSON_ARRAYAGG(JSON_OBJECT('parent_name', coalesce(parent_name,''), 'parent_locator', coalesce(parent_locator, ''),'field_name', field_name,'id', id, 'field_value', field_value)) FROM exposure_characteristics_fields echf
         WHERE is_group = false AND echf.exposure_characteristics_locator = peril_characteristics.exposure_characteristics_locator) AS exposure_fields,
        (SELECT JSON_ARRAYAGG(JSON_OBJECT('parent_name', coalesce(parent_name,''), 'parent_locator', coalesce(parent_locator, ''),'field_name', field_name,'id', id, 'field_value', field_value)) FROM peril_characteristics_fields pchf
         WHERE is_group = false AND pchf.peril_characteristics_locator = peril_characteristics.locator) AS peril_fields
FROM peril_characteristics
JOIN peril ON peril_characteristics.peril_locator = peril.locator
JOIN policy_modification pm ON peril_characteristics.policy_modification_locator = pm.locator
JOIN exposure_characteristics ON peril_characteristics.exposure_characteristics_locator = exposure_characteristics.locator
JOIN policy_characteristics ON peril_characteristics.policy_characteristics_locator = policy_characteristics.locator
JOIN exposure ON exposure_characteristics.exposure_locator = exposure.locator
JOIN policy ON peril_characteristics.policy_locator = policy.locator
WHERE policy.product_name = @productName
    AND peril_characteristics.start_timestamp <= @endTimestamp
    AND peril_characteristics.end_timestamp >= @startTimestamp
    AND peril_characteristics.replaced_timestamp IS NULL;

/**
 * Financial transactions report
 *
 * NOTE: this includes all financial transactions (FTs), including any that were
 * never assigned to issued invoices. If you only want to consider FTs on
 * issued invoices, filter out FTs with NULL `invoice_locator`s.
 */
SET @startTimestamp = unix_timestamp('2022-11-22') * 1000;
SET @endTimestamp = unix_timestamp('2022-12-22') * 1000;

SELECT
      ft.id,
      ft.amount,
      policy.currency,
      ft.posted_timestamp,
      ft.type,
      policy.locator AS policy_locator,
      policy.product_name AS product_name,
      ft.peril_characteristics_locator,
      ft.peril_name,
      ft.tax_name,
      ft.fee_name,
      ft.commission_recipient,
FROM financial_transaction ft JOIN policy ON policy.locator = ft.policy_locator
LEFT JOIN peril_characteristics pc ON pc.locator = ft.peril_characteristics_locator
LEFT JOIN peril ON peril.locator = pc.peril_locator
WHERE ft.posted_timestamp >= @startTimestamp AND ft.posted_timestamp < @endTimestamp

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
 * Unearned premium accounts receivable
 */
SET @reportTimestamp = unix_timestamp('2022-11-22') * 1000;

SELECT * FROM
    (SELECT policy_locator,
           product_name,
           SUM(amount) total_amount,
           SUM(earned_amount) earned_amount,
           SUM(unearned_amount) unearned_amount
    FROM
    (SELECT policy_locator,
           product_name,
           amount,
           ((earnedTimeMillis / coveragePeriodMillis) * amount) earned_amount,
           (amount - ((earnedTimeMillis / coveragePeriodMillis) * amount)) unearned_amount
        FROM
        (SELECT
            p.locator policy_locator,
            p.product_name product_name,
            ft.amount amount,
            (ft.end_timestamp - ft.start_timestamp) coveragePeriodMillis,
            (@reportTimestamp - ft.start_timestamp) earnedTimeMillis
        FROM invoice inv
        JOIN financial_transaction ft ON ft.invoice_locator = inv.locator
        JOIN policy p ON inv.policy_locator = p.locator
        WHERE ft.type = 'premium'
            AND inv.created_timestamp <= @reportTimestamp
            AND ft.end_timestamp >= @reportTimestamp) AS txns) AS txnsWithEarnedUnearned
    GROUP BY policy_locator, product_name) AS intermediateReport
WHERE total_amount > 0
ORDER BY policy_locator ASC;

/**
 * Simple gross written premium metrics
 */
-- GWP agg by product
SET @startTimestmap = unix_timestamp('2022-11-22') * 1000;
SET @endTimestamp = unix_timestamp('2022-12-22') * 1000;

SELECT p.product_name AS product_name, SUM(pc.premium)
FROM peril_characteristics pc
JOIN policy p ON pc.policy_locator = p.locator
WHERE pc.issued_timestamp >= @startTimestamp
    AND pc.issued_timestamp < @endTimestamp
    AND pc.replaced_timestamp IS NULL
GROUP BY p.product_name;

-- GWP agg by policy
SET @startTimestmap = unix_timestamp('2022-11-22') * 1000;
SET @endTimestamp = unix_timestamp('2022-12-22') * 1000;

SELECT p.locator AS policyLocator, SUM(pc.premium)
FROM peril_characteristics pc
JOIN policy p ON pc.policy_locator = p.locator
WHERE pc.issued_timestamp >= @startTimestamp
    AND pc.issued_timestamp < @endTimestamp
    AND pc.replaced_timestamp IS NULL
GROUP BY p.locator;

-- GWP agg by peril characteristics
-- GWP agg by characteristics
SET @startTimestmap = unix_timestamp('2022-11-22') * 1000;
SET @endTimestamp = unix_timestamp('2022-12-22') * 1000;

SELECT pc.premium, policy.product_name AS productName, policy.locator as policyLocator,
       exposure.name AS exposureName, peril.name AS perilName,
       pc.locator AS perilCharacteristicsLocator
FROM peril_characteristics pc
JOIN peril ON pc.peril_locator = peril.locator
JOIN exposure_characteristics ec ON pc.exposure_characteristics_locator = ec.locator
JOIN exposure ON exposure.locator = ec.exposure_locator
JOIN policy ON pc.policy_locator = policy.locator
WHERE pc.issued_timestamp >= @startTimestamp
    AND pc.issued_timestamp < @endTimestamp
    AND pc.replaced_timestamp IS NULL

