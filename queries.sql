--############################## Religion Data ##############################
--###########################################################################
--
--COPY (
--             SELECT
--                 CASE
--                     WHEN LOWER(TRIM(fd.family_religion)) LIKE 'other%'
--                         THEN 'Other'
--                     ELSE TRIM(fd.family_religion)
--                 END AS family_religion,
--                 COUNT(*) AS total_count
--             FROM read_csv_auto('raw_data_input_files/family_details.csv') fd
--             INNER JOIN read_csv_auto('raw_data_input_files/survey_data_CP_2026.csv') sdc
--                 ON sdc.id = fd.id
--             WHERE
--                 sdc.ready_for_survey = 'Yes'
--                 AND CAST(sdc.standardized_date AS DATE) >= DATE '2026-05-05'
--             GROUP BY 1
--             ORDER BY total_count DESC
--         )
--         TO 'family_religion_count_test.csv'
--         (HEADER, DELIMITER ',');
--
----
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


--############ data check #########

--
---- [2] Loan | migrated_member_name : raw vs rep, excused when intl_migrations = 'No'
--WITH raw AS (
--    SELECT id, member_index,
--           NULLIF(trim(CAST("migrated_member_name" AS varchar)), '') AS val
--    FROM loan_details_csv
--),
--rep AS (
--    SELECT id, member_index,
--           NULLIF(trim(CAST("migrated_member_name" AS varchar)), '') AS val
--    FROM loan_details_parquet
--),
--main AS (
--    SELECT id, lower(trim(CAST("intl_migrations" AS varchar))) AS intl_migrations
--    FROM survey_data_csv
--)
--SELECT
--    raw.id,
--    raw.member_index,
--    raw.val AS raw_value,
--    rep.val AS rep_value,
--    main.intl_migrations
--FROM raw
--JOIN rep
--  ON  rep.id           = raw.id
--  AND rep.member_index = raw.member_index    -- one loan row ↔ one loan row
--LEFT JOIN main
--  ON  main.id = raw.id                       -- main is one row per id
--WHERE raw.val IS DISTINCT FROM rep.val       -- check 1: values don't match
--  AND main.intl_migrations = 'yes'          -- check 2: Yes → flag
--ORDER BY raw.id, raw.member_index;


--########## updated check query for single column matching #################
--
--WITH raw AS (
--    SELECT id, member_index,
--           NULLIF(trim(CAST(family_college_type AS varchar)), '') AS val
--    FROM family_details_csv
--),
--rep AS (
--    SELECT id, member_index,
--           NULLIF(trim(CAST(family_college_type AS varchar)), '') AS val
--    FROM family_details_parquet
--),
--main AS (
--    SELECT id,member_index,
--           lower(trim(CAST(family_current_enrollment AS varchar))) AS enrollment,
--           TRY_CAST(trim(CAST(family_age AS varchar)) AS double)   AS family_age
--    FROM family_details_csv
--)
--SELECT
--    raw.id,
--    raw.member_index,
--    raw.val          AS raw_value,
--    rep.val          AS rep_value,
--    main.enrollment  AS family_current_enrollment,
--    main.family_age
--FROM raw
--JOIN rep
--  ON  rep.id           = raw.id
--  AND rep.member_index = raw.member_index
--JOIN main
--  ON  main.id = raw.id
--   AND main.member_index = raw.member_index   -- if survey_data_csv is per-member
--WHERE
--    (CASE WHEN lower(raw.val) LIKE 'other%' THEN 'other' ELSE lower(raw.val) END)
--      IS DISTINCT FROM
--    (CASE WHEN lower(rep.val) LIKE 'other%' THEN 'other' ELSE lower(rep.val) END)
--    AND main.enrollment = 'college'
--    AND main.family_age BETWEEN 6 AND 35
--ORDER BY raw.id, raw.member_index;


--################# Matching multiple columns ####################

-- ---------------------------------------------------------------
-- Helpers
-- clean(): trim, collapse whitespace, lowercase, '' / nan / null -> NULL
-- norm():  clean() + 'other...' -> 'other' + numeric normalisation ('25' = '25.0')
-- ---------------------------------------------------------------
CREATE OR REPLACE TEMP MACRO clean(v) AS (
    CASE
        WHEN lower(trim(CAST(v AS VARCHAR))) IN ('', 'nan', 'none', 'null') THEN NULL
        ELSE lower(regexp_replace(trim(CAST(v AS VARCHAR)), '\s+', ' ', 'g'))
    END
);

CREATE OR REPLACE TEMP MACRO norm(v) AS (
    CASE
        WHEN clean(v) LIKE 'other%' THEN 'other'
        WHEN TRY_CAST(clean(v) AS DOUBLE) IS NOT NULL
             THEN CAST(TRY_CAST(clean(v) AS DOUBLE) AS VARCHAR)
        ELSE clean(v)
    END
);

WITH
-- Parent / condition values, taken from RAW
c AS (
    SELECT
        id, member_index,
        TRY_CAST(clean(family_age) AS DOUBLE)                  AS age,
        clean(family_still_studying)                           AS still_studying,
        clean(family_current_enrollment)                       AS enrollment,
        clean(family_school_type)                              AS school_type,
        clean(family_employment_status)                        AS emp_status,
        clean(family_member_employed_earlier)                  AS employed_earlier,
        clean(family_occupation_member)                        AS occupation,
        clean(family_previous_occupation)                      AS prev_occupation,
        clean(family_retired_govt_employee)                    AS retired_govt,
        clean(family_govt_department)                          AS govt_dept,
        clean(family_caste_category)                           AS caste,
        clean(family_sub_caste)                                AS sub_caste,
        clean(family_drug_problem)                             AS drug_problem,
        clean(family_visit_nmk_centre)                         AS visit_nmk,
        clean(family_last_treatment_visit)                     AS last_visit,
        clean(family_member_admitted_to_rehabilitation_centre) AS rehab,
        clean(family_stopped_treatment_reason)                 AS stopped_reason,
        clean(family_voter_registered_here)                    AS voter_reg,
        clean(family_voter_id)                                 AS voter_id,
        clean(family_lastest_news_sources)                     AS news,
        clean(family_most_used_social_media_platform)          AS social,
        clean(family_relationship)                             AS relationship,
        clean(family_religion)                                 AS religion
    FROM family_details_csv
),

-- One row per (id, member_index, column) with raw value, rep value, applicability
long AS (
    SELECT
        r.id, r.member_index,
        unnest([
            {'column_name': 'family_age', 'raw_value': r.family_age::VARCHAR, 'rep_value': p.family_age::VARCHAR,
             'applicable': true},
            {'column_name': 'family_caste_category', 'raw_value': r.family_caste_category::VARCHAR, 'rep_value': p.family_caste_category::VARCHAR,
             'applicable': true},
            {'column_name': 'family_caste_category_other', 'raw_value': r.family_caste_category_other::VARCHAR, 'rep_value': p.family_caste_category_other::VARCHAR,
             'applicable': c.caste LIKE '%other%'},
            {'column_name': 'family_college_type', 'raw_value': r.family_college_type::VARCHAR, 'rep_value': p.family_college_type::VARCHAR,
             'applicable': c.enrollment = 'college' AND c.age > 5 AND c.age <= 35},
            {'column_name': 'family_contact_number', 'raw_value': r.family_contact_number::VARCHAR, 'rep_value': p.family_contact_number::VARCHAR,
             'applicable': c.age >= 18},
            {'column_name': 'family_current_enrollment', 'raw_value': r.family_current_enrollment::VARCHAR, 'rep_value': p.family_current_enrollment::VARCHAR,
             'applicable': c.still_studying = 'yes'},
            {'column_name': 'family_current_qualification', 'raw_value': r.family_current_qualification::VARCHAR, 'rep_value': p.family_current_qualification::VARCHAR,
             'applicable': c.still_studying = 'yes' OR c.enrollment IN ('school', 'college', 'school or college')},
            {'column_name': 'family_drug_problem', 'raw_value': r.family_drug_problem::VARCHAR, 'rep_value': p.family_drug_problem::VARCHAR,
             'applicable': c.age >= 10},
            {'column_name': 'family_drug_problem_duration', 'raw_value': r.family_drug_problem_duration::VARCHAR, 'rep_value': p.family_drug_problem_duration::VARCHAR,
             'applicable': c.drug_problem = 'yes' AND c.age >= 15},
            {'column_name': 'family_employment_status', 'raw_value': r.family_employment_status::VARCHAR, 'rep_value': p.family_employment_status::VARCHAR,
             'applicable': c.age >= 18},
            {'column_name': 'family_govt_department', 'raw_value': r.family_govt_department::VARCHAR, 'rep_value': p.family_govt_department::VARCHAR,
             'applicable': (c.occupation LIKE 'government salaried employee%'
                            OR c.retired_govt = 'yes'
                            OR c.prev_occupation LIKE 'government salaried employee%')
                           AND c.age >= 18},
            {'column_name': 'family_govt_department_other', 'raw_value': r.family_govt_department_other::VARCHAR, 'rep_value': p.family_govt_department_other::VARCHAR,
             'applicable': c.govt_dept LIKE '%other%'},
            {'column_name': 'family_has_schools_improved_bm_gov', 'raw_value': r.family_has_schools_improved_bm_gov::VARCHAR, 'rep_value': p.family_has_schools_improved_bm_gov::VARCHAR,
             'applicable': c.school_type = 'government' AND c.age > 5 AND c.age <= 35},
            {'column_name': 'family_is_respondent', 'raw_value': r.family_is_respondent::VARCHAR, 'rep_value': p.family_is_respondent::VARCHAR,
             'applicable': true},
            {'column_name': 'family_lastest_news_sources', 'raw_value': r.family_lastest_news_sources::VARCHAR, 'rep_value': p.family_lastest_news_sources::VARCHAR,
             'applicable': c.age >= 18},
            {'column_name': 'family_lastest_news_sources_other', 'raw_value': r.family_lastest_news_sources_other::VARCHAR, 'rep_value': p.family_lastest_news_sources_other::VARCHAR,
             'applicable': c.news LIKE '%other%' AND c.age >= 18},
            {'column_name': 'family_living_status', 'raw_value': r.family_living_status::VARCHAR, 'rep_value': p.family_living_status::VARCHAR,
             'applicable': true},
            {'column_name': 'family_marital_status', 'raw_value': r.family_marital_status::VARCHAR, 'rep_value': p.family_marital_status::VARCHAR,
             'applicable': c.age >= 18},
            {'column_name': 'family_maximum_qualification', 'raw_value': r.family_maximum_qualification::VARCHAR, 'rep_value': p.family_maximum_qualification::VARCHAR,
             'applicable': c.still_studying = 'no' OR c.age > 35},
            {'column_name': 'family_member_admitted_to_rehabilitation_centre', 'raw_value': r.family_member_admitted_to_rehabilitation_centre::VARCHAR, 'rep_value': p.family_member_admitted_to_rehabilitation_centre::VARCHAR,
             'applicable': (c.drug_problem = 'yes'
                            OR c.last_visit LIKE 'less than 3 month%'
                            OR regexp_matches(c.last_visit, '^3 ?months? ?- ?6 ?months?'))
                           AND c.age >= 15},
            {'column_name': 'family_member_employed_earlier', 'raw_value': r.family_member_employed_earlier::VARCHAR, 'rep_value': p.family_member_employed_earlier::VARCHAR,
             'applicable': c.emp_status LIKE 'unemployed, willing to work%' AND c.age >= 18},
            {'column_name': 'family_member_last_additted_to_centre', 'raw_value': r.family_member_last_additted_to_centre::VARCHAR, 'rep_value': p.family_member_last_additted_to_centre::VARCHAR,
             'applicable': (c.rehab LIKE 'yes, completed%' OR c.rehab LIKE 'yes, but discontinued%') AND c.age >= 15},
            {'column_name': 'family_most_used_social_media_platform', 'raw_value': r.family_most_used_social_media_platform::VARCHAR, 'rep_value': p.family_most_used_social_media_platform::VARCHAR,
             'applicable': c.age >= 18},
            {'column_name': 'family_most_used_social_media_platform_other', 'raw_value': r.family_most_used_social_media_platform_other::VARCHAR, 'rep_value': p.family_most_used_social_media_platform_other::VARCHAR,
             'applicable': c.social LIKE '%other%' AND c.age >= 18},
            {'column_name': 'family_occupation_member', 'raw_value': r.family_occupation_member::VARCHAR, 'rep_value': p.family_occupation_member::VARCHAR,
             'applicable': c.emp_status = 'employed' AND c.age >= 18},
            {'column_name': 'family_occupation_member_other', 'raw_value': r.family_occupation_member_other::VARCHAR, 'rep_value': p.family_occupation_member_other::VARCHAR,
             'applicable': c.occupation LIKE '%other%' AND c.emp_status = 'employed' AND c.age >= 18},
            {'column_name': 'family_previous_occupation', 'raw_value': r.family_previous_occupation::VARCHAR, 'rep_value': p.family_previous_occupation::VARCHAR,
             'applicable': c.employed_earlier = 'yes' AND c.age >= 18},
            {'column_name': 'family_previous_occupation_other', 'raw_value': r.family_previous_occupation_other::VARCHAR, 'rep_value': p.family_previous_occupation_other::VARCHAR,
             'applicable': c.prev_occupation LIKE '%other%' AND c.employed_earlier = 'yes' AND c.age >= 18},
            {'column_name': 'family_relationship', 'raw_value': r.family_relationship::VARCHAR, 'rep_value': p.family_relationship::VARCHAR,
             'applicable': true},
            {'column_name': 'family_relationship_other', 'raw_value': r.family_relationship_other::VARCHAR, 'rep_value': p.family_relationship_other::VARCHAR,
             'applicable': c.relationship LIKE '%other%'},
            {'column_name': 'family_religion', 'raw_value': r.family_religion::VARCHAR, 'rep_value': p.family_religion::VARCHAR,
             'applicable': true},
            {'column_name': 'family_religion_other', 'raw_value': r.family_religion_other::VARCHAR, 'rep_value': p.family_religion_other::VARCHAR,
             'applicable': c.religion LIKE '%other%'},
            {'column_name': 'family_retired_govt_employee', 'raw_value': r.family_retired_govt_employee::VARCHAR, 'rep_value': p.family_retired_govt_employee::VARCHAR,
             'applicable': c.emp_status = 'retired' AND c.age >= 18},
            {'column_name': 'family_school_type', 'raw_value': r.family_school_type::VARCHAR, 'rep_value': p.family_school_type::VARCHAR,
             'applicable': c.enrollment = 'school' AND c.age > 5 AND c.age <= 35},
            {'column_name': 'family_share_aadhaar_details', 'raw_value': r.family_share_aadhaar_details::VARCHAR, 'rep_value': p.family_share_aadhaar_details::VARCHAR,
             'applicable': true},
            {'column_name': 'family_still_studying', 'raw_value': r.family_still_studying::VARCHAR, 'rep_value': p.family_still_studying::VARCHAR,
             'applicable': c.age > 5 AND c.age <= 35},
            {'column_name': 'family_stopped_treatment_reason', 'raw_value': r.family_stopped_treatment_reason::VARCHAR, 'rep_value': p.family_stopped_treatment_reason::VARCHAR,
             'applicable': c.visit_nmk LIKE 'used to go but has stopped%' AND c.age >= 15},
            {'column_name': 'family_stopped_treatment_reason_other', 'raw_value': r.family_stopped_treatment_reason_other::VARCHAR, 'rep_value': p.family_stopped_treatment_reason_other::VARCHAR,
             'applicable': c.stopped_reason LIKE '%other%' AND c.visit_nmk LIKE 'used to go but has stopped%' AND c.age >= 15},
            {'column_name': 'family_sub_caste', 'raw_value': r.family_sub_caste::VARCHAR, 'rep_value': p.family_sub_caste::VARCHAR,
             'applicable': c.caste IN ('general', 'vimukt jati', 'sc', 'obc/bc', 'st')},
            {'column_name': 'family_sub_caste_other', 'raw_value': r.family_sub_caste_other::VARCHAR, 'rep_value': p.family_sub_caste_other::VARCHAR,
             'applicable': c.sub_caste LIKE '%other%'},
            {'column_name': 'family_total_monthly_income', 'raw_value': r.family_total_monthly_income::VARCHAR, 'rep_value': p.family_total_monthly_income::VARCHAR,
             'applicable': c.emp_status = 'employed' AND c.age >= 18},
            {'column_name': 'family_visit_nmk_centre', 'raw_value': r.family_visit_nmk_centre::VARCHAR, 'rep_value': p.family_visit_nmk_centre::VARCHAR,
             'applicable': c.drug_problem = 'yes' AND c.age >= 15},
            {'column_name': 'family_voter_id', 'raw_value': r.family_voter_id::VARCHAR, 'rep_value': p.family_voter_id::VARCHAR,
             'applicable': c.voter_reg = 'yes'
                           OR c.voter_reg LIKE 'registered in punjab, but not from this address%'},
            {'column_name': 'family_voter_id_no', 'raw_value': r.family_voter_id_no::VARCHAR, 'rep_value': p.family_voter_id_no::VARCHAR,
             'applicable': c.voter_id = 'yes'},   -- ASSUMPTION: not in the Excel sheet
            {'column_name': 'family_voter_registered_here', 'raw_value': r.family_voter_registered_here::VARCHAR, 'rep_value': p.family_voter_registered_here::VARCHAR,
             'applicable': c.age >= 18}
        ], recursive := true)
    FROM family_details_csv r
    JOIN family_details_parquet p
      ON  p.id           = r.id
      AND p.member_index = r.member_index
    JOIN c
      ON  c.id           = r.id
      AND c.member_index = r.member_index
)

-- ---- Detail: every mismatch ----
--SELECT
--    column_name,
--    id,
--    member_index,
--    raw_value,
--    rep_value
--FROM long
--WHERE COALESCE(applicable, false)
--  AND norm(raw_value) IS DISTINCT FROM norm(rep_value)
--ORDER BY column_name, id, member_index;

-- ---- Summary instead: swap the SELECT above for this one ----
 SELECT column_name,
        count(*) FILTER (WHERE COALESCE(applicable, false))                     AS rows_checked,
        count(*) FILTER (WHERE COALESCE(applicable, false)
                         AND norm(raw_value) IS DISTINCT FROM norm(rep_value))  AS mismatches
 FROM long
 GROUP BY column_name
 ORDER BY mismatches DESC;




-- ############## main table columns mismatch check ################

-- ---------------------------------------------------------------
-- Helpers (same as the family query)
-- ---------------------------------------------------------------
--CREATE OR REPLACE TEMP MACRO clean(v) AS (
--    CASE
--        WHEN lower(trim(CAST(v AS VARCHAR))) IN ('', 'nan', 'none', 'null') THEN NULL
--        ELSE lower(regexp_replace(trim(CAST(v AS VARCHAR)), '\s+', ' ', 'g'))
--    END
--);
--
--CREATE OR REPLACE TEMP MACRO norm(v) AS (
--    CASE
--        WHEN clean(v) LIKE 'other%' THEN 'other'
--        WHEN TRY_CAST(clean(v) AS DOUBLE) IS NOT NULL
--             THEN CAST(TRY_CAST(clean(v) AS DOUBLE) AS VARCHAR)
--        ELSE clean(v)
--    END
--);
--
--WITH
---- Household-level flags rolled up from the RAW family table
--fam AS (
--    SELECT
--        id,
--        bool_or(clean(family_occupation_member)  LIKE 'farmer%'
--             OR clean(family_previous_occupation) LIKE 'farmer%')          AS hh_farmer,
--        bool_or(clean(family_caste_category) IN ('obc/bc', 'sc', 'vimukt jati', 'st')
--             OR clean(family_caste_category) LIKE 'other%')                AS hh_disc_caste
--    FROM family_details_csv
--    GROUP BY id
--),
--
---- Parent / condition values from RAW main table
--c AS (
--    SELECT
--        s.id,
--        clean(s.caste_barriers_services)                         AS caste_barriers,
--        clean(s.benefited_free_bus)                              AS ben_bus,
--        clean(s.caste_discrimination)                            AS caste_disc,
--        clean(s.crime_experience_1yr)                            AS crime_1yr,
--        clean(s.primary_crops)                                   AS crops,
--        clean(s.owns_land_punjab)                                AS owns_land,
--        clean(s.land_type)                                       AS land_type,
--        clean(s.bijli_scheme_satisfaction)                       AS sat_bijli,
--        clean(s.free_bus_satisfaction)                           AS sat_bus,
--        clean(s.free_treatment_satisfaction)                     AS sat_treatment,
--        clean(s.yogshala_satisfaction)                           AS sat_yogshala,
--        clean(s.pension_satisfaction)                            AS sat_pension,
--        clean(s.sarkar_tuade_dwar_satisfaction)                  AS sat_std,
--        clean(s.teerth_yatra_satisfaction)                       AS sat_teerth,
--        clean(s.benefited_govt_pension)                          AS ben_pension,
--        clean(s.campaign_impact)                                 AS campaign_impact,
--        COALESCE(f.hh_farmer, false)
--            OR clean(s.land_type) LIKE '%agriculture (owned)%'   AS is_farmer,
--        COALESCE(f.hh_disc_caste, false)                         AS disc_caste
--    FROM survey_data_csv s
--    LEFT JOIN fam f ON f.id = s.id
--),
--
--long AS (
--    SELECT
--        r.id,
--        unnest([
--            {'column_name': 'barrier_service_type', 'raw_value': r.barrier_service_type::VARCHAR, 'rep_value': p.barrier_service_type::VARCHAR,
--             'applicable': c.caste_barriers = 'yes'},
--            {'column_name': 'bus_monthly_savings', 'raw_value': r.bus_monthly_savings::VARCHAR, 'rep_value': p.bus_monthly_savings::VARCHAR,
--             'applicable': c.ben_bus = 'yes'},
--            {'column_name': 'canal_irrigation_improved', 'raw_value': r.canal_irrigation_improved::VARCHAR, 'rep_value': p.canal_irrigation_improved::VARCHAR,
--             'applicable': c.is_farmer},
--            {'column_name': 'caste_discrimination', 'raw_value': r.caste_discrimination::VARCHAR, 'rep_value': p.caste_discrimination::VARCHAR,
--             'applicable': c.disc_caste},
--            {'column_name': 'common_crime_type', 'raw_value': r.common_crime_type::VARCHAR, 'rep_value': p.common_crime_type::VARCHAR,
--             'applicable': true},
--            {'column_name': 'crime_nature', 'raw_value': r.crime_nature::VARCHAR, 'rep_value': p.crime_nature::VARCHAR,
--             'applicable': c.crime_1yr = 'yes'},
--            {'column_name': 'discrimination_nature', 'raw_value': r.discrimination_nature::VARCHAR, 'rep_value': p.discrimination_nature::VARCHAR,
--             'applicable': c.caste_disc = 'yes'},
--            {'column_name': 'diversify_from_paddy_wheat', 'raw_value': r.diversify_from_paddy_wheat::VARCHAR, 'rep_value': p.diversify_from_paddy_wheat::VARCHAR,
--             'applicable': regexp_matches(c.crops, 'wheat|rice|paddy')},
--            {'column_name': 'drinking_water_source', 'raw_value': r.drinking_water_source::VARCHAR, 'rep_value': p.drinking_water_source::VARCHAR,
--             'applicable': true},
--            {'column_name': 'farm_electricity_hours', 'raw_value': r.farm_electricity_hours::VARCHAR, 'rep_value': p.farm_electricity_hours::VARCHAR,
--             'applicable': c.is_farmer},
--            {'column_name': 'farm_electricity_improved', 'raw_value': r.farm_electricity_improved::VARCHAR, 'rep_value': p.farm_electricity_improved::VARCHAR,
--             'applicable': c.is_farmer},
--            {'column_name': 'first_time_service', 'raw_value': r.first_time_service::VARCHAR, 'rep_value': p.first_time_service::VARCHAR,
--             'applicable': true},
--            {'column_name': 'full_address', 'raw_value': r.full_address::VARCHAR, 'rep_value': p.full_address::VARCHAR,
--             'applicable': true},
--            {'column_name': 'intl_migration', 'raw_value': r.intl_migration::VARCHAR, 'rep_value': p.intl_migration::VARCHAR,
--             'applicable': true},
--            {'column_name': 'irrigation_source', 'raw_value': r.irrigation_source::VARCHAR, 'rep_value': p.irrigation_source::VARCHAR,
--             'applicable': c.is_farmer},
--            {'column_name': 'irrigation_water_shortage', 'raw_value': r.irrigation_water_shortage::VARCHAR, 'rep_value': p.irrigation_water_shortage::VARCHAR,
--             'applicable': c.is_farmer},
--            {'column_name': 'land_type', 'raw_value': r.land_type::VARCHAR, 'rep_value': p.land_type::VARCHAR,
--             'applicable': c.owns_land = 'yes'},
--            {'column_name': 'not_satisfied_bijli_scheme', 'raw_value': r.not_satisfied_bijli_scheme::VARCHAR, 'rep_value': p.not_satisfied_bijli_scheme::VARCHAR,
--             'applicable': c.sat_bijli = 'not happy'},
--            {'column_name': 'not_satisfied_free_bus_yatra', 'raw_value': r.not_satisfied_free_bus_yatra::VARCHAR, 'rep_value': p.not_satisfied_free_bus_yatra::VARCHAR,
--             'applicable': c.sat_bus = 'not happy'},
--            {'column_name': 'not_satisfied_free_treatment_reason', 'raw_value': r.not_satisfied_free_treatment_reason::VARCHAR, 'rep_value': p.not_satisfied_free_treatment_reason::VARCHAR,
--             'applicable': c.sat_treatment = 'not happy'},
--            {'column_name': 'not_satisfied_free_yogshala', 'raw_value': r.not_satisfied_free_yogshala::VARCHAR, 'rep_value': p.not_satisfied_free_yogshala::VARCHAR,
--             'applicable': c.sat_yogshala = 'not happy'},
--            {'column_name': 'not_satisfied_pension_scheme', 'raw_value': r.not_satisfied_pension_scheme::VARCHAR, 'rep_value': p.not_satisfied_pension_scheme::VARCHAR,
--             'applicable': c.sat_pension = 'not happy'},
--            {'column_name': 'not_satisfied_sarkar_tuade_dwar', 'raw_value': r.not_satisfied_sarkar_tuade_dwar::VARCHAR, 'rep_value': p.not_satisfied_sarkar_tuade_dwar::VARCHAR,
--             'applicable': c.sat_std = 'not happy'},
--            {'column_name': 'not_satisfied_teerth_yatra', 'raw_value': r.not_satisfied_teerth_yatra::VARCHAR, 'rep_value': p.not_satisfied_teerth_yatra::VARCHAR,
--             'applicable': c.sat_teerth = 'not happy'},
--            {'column_name': 'owns_car', 'raw_value': r.owns_car::VARCHAR, 'rep_value': p.owns_car::VARCHAR,
--             'applicable': true},
--            {'column_name': 'owns_two_wheeler', 'raw_value': r.owns_two_wheeler::VARCHAR, 'rep_value': p.owns_two_wheeler::VARCHAR,
--             'applicable': true},
--            {'column_name': 'pension_monthly_income', 'raw_value': r.pension_monthly_income::VARCHAR, 'rep_value': p.pension_monthly_income::VARCHAR,
--             'applicable': c.ben_pension = 'yes'},
--            {'column_name': 'primary_crops', 'raw_value': r.primary_crops::VARCHAR, 'rep_value': p.primary_crops::VARCHAR,
--             'applicable': c.is_farmer},
--            {'column_name': 'primary_healthcare_source', 'raw_value': r.primary_healthcare_source::VARCHAR, 'rep_value': p.primary_healthcare_source::VARCHAR,
--             'applicable': true},
--            {'column_name': 'ready_for_survey', 'raw_value': r.ready_for_survey::VARCHAR, 'rep_value': p.ready_for_survey::VARCHAR,
--             'applicable': true},
--            {'column_name': 'top3_priority_issues', 'raw_value': r.top3_priority_issues::VARCHAR, 'rep_value': p.top3_priority_issues::VARCHAR,
--             'applicable': true},
--            {'column_name': 'top5_govt_works', 'raw_value': r.top5_govt_works::VARCHAR, 'rep_value': p.top5_govt_works::VARCHAR,
--             'applicable': true},
--            {'column_name': 'urgent_infra_need', 'raw_value': r.urgent_infra_need::VARCHAR, 'rep_value': p.urgent_infra_need::VARCHAR,
--             'applicable': true},
--            {'column_name': 'yudh_nashe_impact', 'raw_value': r.yudh_nashe_impact::VARCHAR, 'rep_value': p.yudh_nashe_impact::VARCHAR,
--             'applicable': c.campaign_impact LIKE 'yes, significant%' OR c.campaign_impact LIKE 'yes, limited%'}
--        ], recursive := true)
--    FROM survey_data_csv r
--    JOIN survey_data_parquet p ON p.id = r.id
--    JOIN c                     ON c.id = r.id
--)

---- ---- Detail: every mismatch ----
--SELECT
--    column_name,
--    id,
--    raw_value,
--    rep_value
--FROM long
--WHERE COALESCE(applicable, false)
--  AND norm(raw_value) IS DISTINCT FROM norm(rep_value)
--ORDER BY column_name, id;
--
---- ---- Summary instead: swap the SELECT above for this one ----
-- SELECT column_name,
--        count(*) FILTER (WHERE COALESCE(applicable, false))                     AS rows_checked,
--        count(*) FILTER (WHERE COALESCE(applicable, false)
--                         AND norm(raw_value) IS DISTINCT FROM norm(rep_value))  AS mismatches
-- FROM long
-- GROUP BY column_name
-- ORDER BY mismatches DESC;