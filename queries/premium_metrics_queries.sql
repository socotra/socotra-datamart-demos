/**
 * Earned premium
 *
 * Note: this example summarizes earned premium as of a given time.
 * Alterations would be needed if retroactive changes need to be included
 * in calculations.
 */
SET @asOfTimestamp = UNIX_TIMESTAMP() * 1000;

SELECT pc_earned_premiums.policy_locator,
       pc_earned_premiums.peril_locator,
       SUM(pc_earned_premiums.prorated_premium) earned_premium
FROM
    (SELECT p.locator policy_locator,
            pc.peril_locator peril_locator,
                  CASE
                      WHEN(pc.end_timestamp > @asOfTimestamp)
                           THEN pc.premium *
                                (TIMESTAMPDIFF(DAY, FROM_UNIXTIME(pc.start_timestamp/1000),
                                    FROM_UNIXTIME(@as_of_timestamp/1000)) /
                                 TIMESTAMPDIFF(DAY, FROM_UNIXTIME(pc.start_timestamp/1000),
                                     FROM_UNIXTIME(pc.end_timestamp/1000)))
                            ELSE pc.premium
                      END AS prorated_premium
    FROM peril_characteristics pc
    JOIN policy p ON pc.policy_locator = p.locator
    WHERE
        pc.issued_timestamp < @asOfTimestamp
           AND pc.start_timestamp < @asOfTimestamp
           AND (pc.replaced_timestamp IS NULL OR pc.replaced_timestamp > @asOfTimestamp)) pc_earned_premiums
GROUP BY pc_earned_premiums.policy_locator, pc_earned_premiums.peril_locator;


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
    AND pc.replaced_timestamp IS NULL;