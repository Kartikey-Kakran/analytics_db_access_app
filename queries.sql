--############################## Religion Data ##############################
--###########################################################################

COPY (
             SELECT
                 CASE
                     WHEN LOWER(TRIM(fd.family_religion)) LIKE 'other%'
                         THEN 'Other'
                     ELSE TRIM(fd.family_religion)
                 END AS family_religion,
                 COUNT(*) AS total_count
             FROM read_csv_auto('raw_data_input_files/family_details.csv') fd
             INNER JOIN read_csv_auto('raw_data_input_files/survey_data_CP_2026.csv') sdc
                 ON sdc.id = fd.id
             WHERE
                 sdc.ready_for_survey = 'Yes'
                 AND CAST(sdc.standardized_date AS DATE) >= DATE '2026-05-05'
             GROUP BY 1
             ORDER BY total_count DESC
         )
         TO 'family_religion_count_test.csv'
         (HEADER, DELIMITER ',');

--
--############################## Caste Category Data ##############################
--#################################################################################
--
--COPY (
--             SELECT
--                 CASE
--                     WHEN LOWER(TRIM(fd.family_caste_category)) LIKE 'other%'
--                         THEN 'Other'
--                     ELSE TRIM(fd.family_caste_category)
--                 END AS family_caste_category,
--                 COUNT(*) AS total_count
--             FROM read_csv_auto('family_details.csv') fd
--             INNER JOIN read_csv_auto('survey_data_CP_2026.csv') sdc
--                 ON sdc.id = fd.id
--             WHERE
--                 sdc.ready_for_survey = 'Yes'
--                 AND CAST(sdc.standardized_date AS DATE) >= DATE '2026-05-05'
--             GROUP BY 1
--             ORDER BY total_count DESC
--         )
--         TO 'family_caste_category_count.csv'
--         (HEADER, DELIMITER ',');
--
--
--############################## Sub-Caste Data ##############################
--############################################################################
--
--COPY (
--             SELECT
--                 CASE
--                     WHEN LOWER(TRIM(fd.family_caste_category)) LIKE 'other%'
--                         THEN 'Other'
--                     WHEN LOWER(TRIM(fd.family_sub_caste)) LIKE 'other%'
--                         THEN 'Other'
--                     ELSE TRIM(fd.family_sub_caste)
--                 END AS family_sub_caste,
--                 COUNT(*) AS total_count
--             FROM read_csv_auto('family_details.csv') fd
--             INNER JOIN read_csv_auto('survey_data_CP_2026.csv') sdc
--                 ON sdc.id = fd.id
--             WHERE
--                 sdc.ready_for_survey = 'Yes'
--                 AND CAST(sdc.standardized_date AS DATE) >= DATE '2026-05-05'
--             GROUP BY 1
--             ORDER BY total_count DESC
--         )
--         TO 'family_sub_caste_count_updated.csv'
--         (HEADER, DELIMITER ',');
--
--
--############################## Religion, Caste, Sub-Caste Data ##############################
--#############################################################################################
--
--
--COPY (
--    SELECT
--        TRIM(fd.family_religion) AS family_religion,
--
--        CASE
--            WHEN LOWER(TRIM(fd.family_caste_category)) LIKE '%other%'
--                THEN 'Other'
--            ELSE TRIM(fd.family_caste_category)
--        END AS family_caste_category,
--
--        CASE
--            WHEN LOWER(TRIM(fd.family_caste_category)) LIKE '%other%'
--                THEN 'Other'
--            WHEN LOWER(TRIM(fd.family_sub_caste)) LIKE '%other%'
--                THEN 'Other'
--            ELSE TRIM(fd.family_sub_caste)
--        END AS family_sub_caste,
--
--        COUNT(*) AS total_count
--
--    FROM read_csv_auto('family_details.csv') fd
--
--    INNER JOIN read_csv_auto('survey_data_CP_2026.csv') sdc
--        ON sdc.id = fd.id
--
--    WHERE
--        sdc.ready_for_survey = 'Yes'
--        AND CAST(sdc.standardized_date AS DATE) >= DATE '2026-05-05'
--
--    GROUP BY 1, 2, 3
--
--    ORDER BY 1, 2, 3
--)
--TO 'religion_caste_subcaste_count_all_up_new.csv'
--(HEADER, DELIMITER ',');
