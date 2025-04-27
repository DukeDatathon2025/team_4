-- Final version:

WITH 
rbc_transfusion_pts_io AS ( 
  SELECT *
  FROM `physionet-data.eicu_crd.intakeoutput`
  WHERE celllabel IN (
    'pRBCs',
    'Volume-Transfuse red blood cells',
    'PRBC',
    'Volume (ml)-Transfuse - Leukoreduced Packed RBCs'
  )
),
rbc_counts AS (
  SELECT
    patientunitstayid,
    COUNT(*) AS transfusion_count
  FROM rbc_transfusion_pts_io
  GROUP BY patientunitstayid
),
single_transfusion_pts AS (
  SELECT patientunitstayid
  FROM rbc_counts
  WHERE transfusion_count = 1
),
multiple_transfusion_pts AS (
  SELECT patientunitstayid
  FROM rbc_counts
  WHERE transfusion_count > 1
),
rbc_with_rownum AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY patientunitstayid ORDER BY intakeoutputoffset) AS rn
  FROM rbc_transfusion_pts_io
  WHERE patientunitstayid IN (SELECT patientunitstayid FROM multiple_transfusion_pts)
),
first_second_diff AS (
  SELECT
    patientunitstayid,
    MAX(CASE WHEN rn = 1 THEN intakeoutputoffset END) AS first_offset,
    MAX(CASE WHEN rn = 2 THEN intakeoutputoffset END) AS second_offset
  FROM rbc_with_rownum
  GROUP BY patientunitstayid
),
eligible_multiple_transfusion_pts AS (
  SELECT patientunitstayid
  FROM first_second_diff
  WHERE (second_offset - first_offset) > 720
),
dialysis_patients AS (
  SELECT DISTINCT patientunitstayid
  FROM `physionet-data.eicu_crd_derived.crrt_dataset`
),
patient_hospital_status AS (
  SELECT patientunitstayid, hospitaldischargestatus, hospitaldischargeoffset, age, gender, ethnicity, hospitalid
  FROM `physionet-data.eicu_crd.patient`
),
apache_scores AS (
  SELECT patientunitstayid, apachescore
  FROM `physionet-data.eicu_crd.apachepatientresult`
  WHERE apacheversion = 'IVa'
),
chronic_hypoxia_patients AS (
  SELECT DISTINCT patientunitstayid
  FROM `physionet-data.eicu_crd.diagnosis`
  WHERE LOWER(diagnosisstring) LIKE '%chronic obstructive pulmonary disease%'
     OR LOWER(diagnosisstring) LIKE '%emphysema%'
     OR LOWER(diagnosisstring) LIKE '%chronic bronchitis%'
     OR LOWER(diagnosisstring) LIKE '%asthma%'
     OR LOWER(diagnosisstring) LIKE '%bronchiectasis%'
     OR LOWER(diagnosisstring) LIKE '%pulmonary fibrosis%'
     OR LOWER(diagnosisstring) LIKE '%interstitial lung disease%'
     OR LOWER(diagnosisstring) LIKE '%pulmonary hypertension%'
     OR LOWER(diagnosisstring) LIKE '%cystic fibrosis%'
     OR LOWER(diagnosisstring) LIKE '%obstructive sleep apnea%'
     OR LOWER(diagnosisstring) LIKE '%cor pulmonale%'
     OR LOWER(diagnosisstring) LIKE '%chronic respiratory failure%'
),
oxygen_info AS (
  SELECT
    a.patientunitstayid AS a_patientunitstayid,
    a.intakeoutputoffset,
    b.chartoffset,
    b.o2_device_group,
    b.final_fio2,
    ROW_NUMBER() OVER (PARTITION BY a.patientunitstayid, a.intakeoutputoffset ORDER BY b.chartoffset DESC) AS rn
  FROM `dukedatathon2025.team_4.patients_offset` a
  LEFT JOIN `dukedatathon2025.team_4.final_o2_cleaned` b
    ON a.patientunitstayid = b.patientunitstayid
  WHERE b.patientunitstayid IS NOT NULL
    AND b.chartoffset < a.intakeoutputoffset
),
oxygen_info_filtered AS (
  SELECT 
    a_patientunitstayid,
    intakeoutputoffset,
    o2_device_group,
    final_fio2
  FROM oxygen_info
  WHERE rn = 1
),
final_selected_single_pts AS (
  SELECT 
    --a.intakeoutputid,
    a.patientunitstayid,
    a.intakeoutputoffset,
    --a.intaketotal, 
    --a.outputtotal, 
    --a.dialysistotal, 
    --a.nettotal, 
    --a.intakeoutputentryoffset,
    --a.cellpath, 
    --a.celllabel,
    --a.cellvaluenumeric,
    --a.cellvaluetext,
    CASE WHEN a.patientunitstayid IN (SELECT patientunitstayid FROM dialysis_patients) THEN 1 ELSE 0 END AS received_dialysis,
    p.hospitaldischargestatus, 
    p.hospitaldischargeoffset, 
    p.age, 
    p.ethnicity, 
    p.gender,
    ap.apachescore,
    (p.hospitaldischargeoffset - a.intakeoutputoffset) AS los_minutes, 
    p.hospitalid,
    CASE WHEN ch.patientunitstayid IS NOT NULL THEN 1 ELSE 0 END AS chronically_hypoxic
  FROM rbc_transfusion_pts_io a
  LEFT JOIN patient_hospital_status p ON a.patientunitstayid = p.patientunitstayid
  LEFT JOIN apache_scores ap ON a.patientunitstayid = ap.patientunitstayid
  LEFT JOIN chronic_hypoxia_patients ch ON a.patientunitstayid = ch.patientunitstayid
  WHERE a.patientunitstayid IN (SELECT patientunitstayid FROM single_transfusion_pts)
),
final_selected_multiple_pts AS (
  SELECT 
    --a.intakeoutputid,
    a.patientunitstayid,
    a.intakeoutputoffset,
    --a.intaketotal, 
    --a.outputtotal, 
    --a.dialysistotal, 
    --a.nettotal, 
    --a.intakeoutputentryoffset,
    --a.cellpath, 
    --a.celllabel,
    --a.cellvaluenumeric,
    --a.cellvaluetext,
    CASE WHEN a.patientunitstayid IN (SELECT patientunitstayid FROM dialysis_patients) THEN 1 ELSE 0 END AS received_dialysis,
    p.hospitaldischargestatus, 
    p.hospitaldischargeoffset, 
    p.age, 
    p.ethnicity, 
    p.gender,
    ap.apachescore,
    (p.hospitaldischargeoffset - a.intakeoutputoffset) AS los_minutes, 
    p.hospitalid,
    CASE WHEN ch.patientunitstayid IS NOT NULL THEN 1 ELSE 0 END AS chronically_hypoxic
  FROM rbc_with_rownum a
  LEFT JOIN patient_hospital_status p ON a.patientunitstayid = p.patientunitstayid
  LEFT JOIN apache_scores ap ON a.patientunitstayid = ap.patientunitstayid
  LEFT JOIN chronic_hypoxia_patients ch ON a.patientunitstayid = ch.patientunitstayid
  WHERE rn = 1
    AND a.patientunitstayid IN (SELECT patientunitstayid FROM eligible_multiple_transfusion_pts)
),
all_pts AS (
  SELECT *
  FROM final_selected_single_pts
  WHERE received_dialysis = 0 
    AND los_minutes >= 0
    AND intakeoutputoffset >= 0

  UNION ALL

  SELECT *
  FROM final_selected_multiple_pts
  WHERE received_dialysis = 0 
    AND los_minutes >= 0
    AND intakeoutputoffset >= 0
),
auc_info AS (
  SELECT DISTINCT
    patientunitstayid,
    avg_sf_pre,
    auc_change
  FROM `dukedatathon2025.team_4.final_avg_auc`
)

SELECT
  a.*,
  b.o2_device_group,
  b.final_fio2 AS baseline_fio2,
  c.avg_sf_pre AS pre_trans_avg_sf,
  c.auc_change AS delta_auc
FROM all_pts a
LEFT JOIN oxygen_info_filtered b
  ON a.patientunitstayid = b.a_patientunitstayid
  AND a.intakeoutputoffset = b.intakeoutputoffset
LEFT JOIN auc_info c
  ON a.patientunitstayid = c.patientunitstayid
WHERE auc_change IS NOT NULL
;





