/**
 * A collection of Data Mart-equivalent queries for the
 * Socotra standard reports set (https://docs.socotra.com/production/data/reporting.html)
 */


/**
 * On Risk report
 *
 * Field values at various levels aggregated
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
 * All Policies report
 *
 * Field values at various levels aggregated
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
 * Financial Transactions report
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
      ft.commission_recipient
FROM financial_transaction ft JOIN policy ON policy.locator = ft.policy_locator
LEFT JOIN peril_characteristics pc ON pc.locator = ft.peril_characteristics_locator
LEFT JOIN peril ON peril.locator = pc.peril_locator
WHERE ft.posted_timestamp >= @startTimestamp AND ft.posted_timestamp < @endTimestamp;

/**
 * Unearned Premium Accounts Receivable report
 */
SET @reportTimestamp = unix_timestamp('2022-11-22') * 1000;
SET @currencyDecimal = 2; -- affects rounding
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
           (amount - round(((unearnedTimeMillis / coveragePeriodMillis) * amount), @currencyDecimal)) earned_amount,
           round(((unearnedTimeMillis / coveragePeriodMillis) * amount), @currencyDecimal) unearned_amount
        FROM
        (SELECT
            p.locator policy_locator,
            p.product_name product_name,
            ft.amount amount,
            (ft.end_timestamp - ft.start_timestamp) coveragePeriodMillis,
            IF(@reportTimestamp < ft.end_timestamp,
                ft.end_timestamp - @reportTimestamp,
                0) unearnedTimeMillis
        FROM invoice inv
        JOIN financial_transaction ft ON ft.invoice_locator = inv.locator
        JOIN policy p ON inv.policy_locator = p.locator
        WHERE ft.type = 'premium'
            AND inv.created_timestamp <= @reportTimestamp) AS txns) AS txnsWithEarnedUnearned
    GROUP BY policy_locator, product_name) AS intermediateReport
WHERE unearned_amount != 0 -- omit to include fully-earned records as well
ORDER BY policy_locator ASC;

/**
 * Paid Financial Transactions report
 */
SET @startTimestamp = unix_timestamp('2022-11-22') * 1000;
SET @endTimestamp = unix_timestamp('2022-12-22') * 1000;

SELECT
        ft.id,
        ft.amount,
        policy.currency,
        ft.posted_timestamp,
        ft.type,
        ft.invoice_locator AS invoice_locator,
        policy.locator AS policy_locator,
        policy.product_name AS product_name,
        ft.peril_characteristics_locator,
        ft.peril_name,
        ft.tax_name,
        ft.fee_name,
        ft.commission_recipient,
        i.locator AS invoice_locator,
        i.created_timestamp AS invoice_created_timestamp,
        i.due_timestamp AS invoice_due_timestamp,
        invoice_payment.posted_timestamp AS payment_posted_timestamp,
        exposure_characteristics.exposure_locator AS exposure_id,
        policy_modification.name AS modification_name
FROM financial_transaction ft
JOIN policy ON policy.locator = ft.policy_locator
JOIN invoice i ON i.locator = ft.invoice_locator
JOIN invoice_payment ON invoice_payment.invoice_locator = i.locator
    AND invoice_payment.reverse_timestamp IS NULL
JOIN policy_modification ON policy_modification.locator = ft.policy_modification_locator
LEFT JOIN peril_characteristics pc ON pc.locator = ft.peril_characteristics_locator
LEFT JOIN peril ON peril.locator = pc.peril_locator
LEFT JOIN exposure_characteristics ON exposure_characteristics.locator = pc.exposure_characteristics_locator
WHERE i.status = 'paid'
AND invoice_payment.posted_timestamp >= @startTimestamp
AND invoice_payment.posted_timestamp < @endTimestamp;

/**
 * Payable Commissions report
 */
SET @startTimestamp = unix_timestamp('2022-11-22') * 1000;
SET @endTimestamp = unix_timestamp('2022-12-22') * 1000;

SELECT policy.locator policy_locator,
       policy.product_name,
       exposure.locator exposure_locator,
       exposure.name exposure_name,
       premium_and_commission.peril_locator,
       peril.name peril_name,
       premium_and_commission.commission_recipient,
       premium_and_commission.peril_invoice_premium peril_premium,
       premium_and_commission.peril_invoice_commission commission_amount
FROM
    (SELECT
           commission_summary.peril_locator,
           commission_summary.peril_invoice_commission,
           commission_summary.commission_recipient,
           premium_summary.peril_invoice_premium
    FROM
        (SELECT
            pc.peril_locator,
            -1 * SUM(ft.amount) AS peril_invoice_commission,
            ft.commission_recipient
        FROM invoice i
        JOIN financial_transaction ft ON ft.invoice_locator = i.locator
        JOIN peril_characteristics pc ON pc.locator = ft.peril_characteristics_locator
        WHERE i.status = 'paid'
          AND i.updated_timestamp >= @startTimestamp
          AND i.updated_timestamp < @endTimestamp
          AND ft.type='commission'
        GROUP BY pc.peril_locator, ft.commission_recipient) commission_summary
    JOIN
        (SELECT
            pc.peril_locator,
            SUM(ft.amount) AS peril_invoice_premium
        FROM invoice i
        JOIN financial_transaction ft ON ft.invoice_locator = i.locator
        JOIN peril_characteristics pc on pc.locator = ft.peril_characteristics_locator
        WHERE i.status='paid'
          AND i.updated_timestamp >= @startTimestamp
          AND i.updated_timestamp < @endTimestamp
          AND ft.type = 'premium'
        GROUP BY pc.peril_locator) premium_summary
    ON commission_summary.peril_locator=premium_summary.peril_locator) premium_and_commission
JOIN peril ON premium_and_commission.peril_locator = peril.locator
JOIN exposure ON peril.exposure_locator = exposure.locator
JOIN policy ON policy.locator = exposure.policy_locator;


/**
 * Claims report
 */
SET @asOfTimestamp = unix_timestamp('2022-11-22') * 1000;

SELECT
    p.policyholder_locator,
    p.locator AS policy_locator,
    c.locator AS claim_locator,
    c.created_timestamp AS created_timestamp,
    c.product_name AS product_name,
    sc.loss_reserve_id AS loss_reserve_id,
    sc.expense_reserve_id AS expense_reserve_id,
    claim_versions.claim_status AS claim_status,
    claim_versions.incident_timestamp AS incident_timestamp,
    claim_versions.notification_timestamp AS notification_timestamp
FROM claim c
INNER JOIN
(SELECT ranked_claim_versions.claim_version_id claim_version_id,
        ranked_claim_versions.claim_locator claim_locator,
        ranked_claim_versions.claim_status claim_status,
        ranked_claim_versions.incident_timestamp incident_timestamp,
        ranked_claim_versions.notification_timestamp notification_timestamp
    FROM
    (SELECT RANK()
        OVER (PARTITION BY cv.claim_locator
              ORDER BY cv.created_timestamp DESC) claim_locator_rank,
            cv.id claim_version_id,
            cv.claim_locator claim_locator,
            cv.claim_status,
            cv.incident_timestamp,
            cv.notification_timestamp
     FROM claim_version cv
     WHERE cv.created_timestamp <= @asOfTimestamp) ranked_claim_versions
WHERE ranked_claim_versions.claim_locator_rank = 1) claim_versions
ON claim_versions.claim_locator = c.locator
LEFT JOIN sub_claim sc ON sc.claim_locator = c.locator
INNER JOIN policy p ON c.policy_locator = p.locator
WHERE c.created_timestamp <= @asOfTimestamp
AND c.discarded = FALSE
ORDER BY c.created_timestamp ASC;

/**
 * Claim Reserves report
 */
SET @asOfTimestamp = unix_timestamp('2022-11-22') * 1000;

SELECT
    p.policyholder_locator,
    p.locator AS policy_locator,
    c.locator AS claim_locator,
    sc.locator AS sub_claim_locator,
    sc.loss_reserve_id AS loss_reserve_id,
    sc.expense_reserve_id AS expense_reserve_id,
    p.product_name,
    peril.locator AS peril_locator,
    peril.name AS peril_name,
    (
        SELECT claim_status
        FROM claim_version cv
        WHERE cv.claim_locator = c.locator
          AND cv.created_timestamp <= @asOfTimestamp
        ORDER BY cv.id DESC
        LIMIT 1
    ) AS claim_status
FROM sub_claim sc
JOIN claim c ON sc.claim_locator = c.locator
JOIN policy p ON sc.policy_locator = p.locator
JOIN peril ON sc.peril_locator = peril.locator
WHERE sc.created_timestamp <= @asOfTimestamp;

/**
 * Claims Payables report
 */
SET @startTimestamp = unix_timestamp('2022-11-22') * 1000;
SET @endTimestamp = unix_timestamp('2022-12-22') * 1000;

SELECT
    policy.policyholder_locator,
    policy.locator policy_locator,
    policy.currency,
    c.product_name,
    e.locator exposure_locator,
    e.name exposure_name,
    peril.locator peril_locator,
    peril.name,
    c.locator claim_id,
    sc.locator subclaim_id,
    sc.created_timestamp subclaim_created_timestamp,
    cp.locator payable_id,
    cp.amount payable_amount,
    cp.reserve_type,
    cp.recipient,
    cp.comment,
    IF(reversal.locator IS NULL, 'false', 'true') was_reversed,
    reversal.comment reversal_comment
FROM claim c
JOIN policy ON c.policy_locator = policy.locator
JOIN sub_claim sc ON sc.claim_locator = c.locator
JOIN peril ON sc.peril_locator = peril.locator
JOIN exposure e ON e.locator = peril.exposure_locator
JOIN claim_payable cp ON cp.sub_claim_locator = sc.locator
LEFT JOIN claim_payable reversal ON
    reversal.reversed_locator = cp.locator
    AND cp.created_timestamp >= @startTimestamp
    AND cp.created_timestamp < @endTimestamp
    AND cp.reversed_locator IS NULL
ORDER BY cp.created_timestamp ASC;