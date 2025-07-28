DELETE FROM `dwh-storage-327422.neobank.neobank_r2_revenue` WHERE snap_dt_part = CURRENT_DATE;

INSERT INTO `dwh-storage-327422.neobank.neobank_r2_revenue`

SELECT DISTINCT
        fin.country_name,
        fin.country_id,
        fin.financing_id,
        fin.user_id,
        dr.driver_id AS external_merchant_id,
        ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) as loan_num,
        fin.financing_status as status_prod,
        CASE 
          WHEN fin.financing_type = 'REGULAR' AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 'FIRST'
          WHEN fin.financing_type = 'REGULAR' AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) > 1 THEN 'REPEAT'
          ELSE 'REFILL'
        END AS loan_num_status,   
        CASE
          WHEN fin.financing_status = 'PAID' AND col.last_collection_date <= fin.due_date THEN 'PAID_IN_TERM'
          WHEN fin.financing_status = 'PAID' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 THEN 'PAID_IN_60_DAY_DEFAULT'
          WHEN fin.financing_status = 'PAID' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -90 THEN 'PAID_IN_90_DAY_DEFAULT'
          WHEN fin.financing_status = 'PAID' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) < -90 THEN 'PAID_AFTER_WRITE-OFF'
          WHEN status = 'DEFAULT' AND DATE_DIFF(fin.due_date, current_date, DAY) >= -15 THEN '15_DAY_DEFAULT'
          WHEN status = 'DEFAULT' AND DATE_DIFF(fin.due_date, current_date, DAY) < -15 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -30 THEN '30_DAY_DEFAULT'
          WHEN status = 'DEFAULT' AND DATE_DIFF(fin.due_date, current_date, DAY) < -30 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -60 THEN '60_DAY_DEFAULT'
          WHEN status = 'DEFAULT' AND DATE_DIFF(fin.due_date, current_date, DAY) < -60 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -90 THEN '90_DAY_DEFAULT'
          WHEN status = 'PAUSE' AND DATE_DIFF(fin.due_date, current_date, DAY) >= -15 THEN '15_DAY_DEFAULT_PAUSE'
          WHEN status = 'PAUSE' AND DATE_DIFF(fin.due_date, current_date, DAY) < -15 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -30 THEN '30_DAY_DEFAULT_PAUSE'
          WHEN status = 'PAUSE' AND DATE_DIFF(fin.due_date, current_date, DAY) < -30 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -60 THEN '60_DAY_DEFAULT_PAUSE'
          WHEN status = 'PAUSE' AND DATE_DIFF(fin.due_date, current_date, DAY) < -60 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -90 THEN '90_DAY_DEFAULT_PAUSE'
          WHEN status = 'CANCELED' AND DATE_DIFF(fin.due_date, current_date, DAY) >= -15 THEN '15_DAY_DEFAULT_CANCELED'
          WHEN status = 'CANCELED' AND DATE_DIFF(fin.due_date, current_date, DAY) < -15 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -30 THEN '30_DAY_DEFAULT_CANCELED'
          WHEN status = 'CANCELED' AND DATE_DIFF(fin.due_date, current_date, DAY) < -30 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -60 THEN '60_DAY_DEFAULT_CANCELED'
          WHEN status = 'CANCELED' AND DATE_DIFF(fin.due_date, current_date, DAY) < -60 AND DATE_DIFF(fin.due_date, current_date, DAY) >= -90 THEN '90_DAY_DEFAULT_CANCELED'                    
          WHEN status = 'WRITE-OFF' THEN 'WRITE-OFF'
          ELSE 'ACTIVE'
        END AS loan_npl_status,               
        fin.start_date as loan_start_date,
        col.last_collection_date, 
        DATE_DIFF(fin.due_date, col.last_collection_date, DAY) as last_collection_date_to_due_date_days,  
        fin.due_date,  
        cur.usd_rate as usd_rate_at_last_collection_date,
        fin.repayment_rate,
        fin.total_repayment_amount as total_repayment_amount_local,
        fin.total_repayment_amount / cur.usd_rate as total_repayment_amount_usd,
        fin.fga_fee / fin.disbursed_amount AS fga_rate,  
        fin.fga_fee AS fga_sum_local,
        fin.fga_fee / cur.usd_rate as fga_sum_usd,
        fin.disbursed_amount as disbursed_amount_local, 
        fin.disbursed_amount / cur.usd_rate as disbursed_amount_usd,
        fin.paid_amount as paid_total_local,
        fin.paid_amount / cur.usd_rate as paid_total_usd, 
        fin.interest_amount AS fixed_fee_local,
        fin.interest_amount / cur.usd_rate AS fixed_fee_usd,
        CASE
          WHEN fin.country_id = 12 THEN 0.16
          WHEN fin.country_id = 22 THEN 0.19
          WHEN fin.country_id = 24 THEN 0.18
        END AS vat,
        CASE  
          -- Collaboration agreement prior to 30/11/2023 (ONLY MEXICO)
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 7.0
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 2.1
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 1.05          

          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 10.0
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 3.0
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 1.50

          -- Collaboration agreement prior to 01/12/2024 - 31/07/2024
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 7.0
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 2.1
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 1.050         

          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 7.5          
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 2.25
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 1.125

          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 5.5
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 1.65
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN 0.825         

          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 6.0          
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 1.80
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN 0.9

          -- Regional collaboration agreement effective date 01/08/2024        
          WHEN fin.country_id IN (12, 22, 24) AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND col.last_collection_date <= fin.due_date THEN 7.5          
          WHEN fin.country_id IN (12, 22, 24) AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 THEN 2.25
          WHEN fin.country_id IN (12, 22, 24) AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 THEN 1.125

          ELSE 0
        END AS percent_from_fee,

        CASE
          -- Collaboration agreement prior to 30/11/2023 (ONLY MEXICO)
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (7.0 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (2.1 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (1.05 / 100.0) * 100 / 116

          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (10.0 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (3.0 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (1.50 / 100.0) * 100 / 116

          -- Collaboration agreement prior to 01/12/2024 - 31/07/2024
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (7.0 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (2.1 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (1.050 / 100.0) * 100 / 116

          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (7.5 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (2.25 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (1.125 / 100.0) * 100 / 116

          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (5.5 / 100.0) * 100 / 119
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (1.65 / 100.0) * 100 / 119
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (0.825 / 100.0) * 100 / 119

          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (6.0 / 100.0) * 100 / 119
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (1.80 / 100.0) * 100 / 119
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (0.9 / 100.0) * 100 / 119

          -- Regional collaboration agreement effective date 01/08/2024        
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND col.last_collection_date <= fin.due_date THEN fin.interest_amount * (7.5 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 THEN fin.interest_amount * (2.25 / 100.0) * 100 / 116
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 THEN fin.interest_amount * (1.125 / 100.0) * 100 / 116

          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND col.last_collection_date <= fin.due_date THEN fin.interest_amount * (7.5 / 100.0) * 100 / 119
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 THEN fin.interest_amount * (2.25 / 100.0) * 100 / 119
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 THEN fin.interest_amount * (1.125 / 100.0) * 100 / 119  

          WHEN fin.country_id = 24 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND col.last_collection_date <= fin.due_date THEN COALESCE(off.interest_amount, off_2.fixed_fee) * (7.5 / 100.0)
          WHEN fin.country_id = 24 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 THEN COALESCE(off.interest_amount, off_2.fixed_fee) * (2.25 / 100.0)
          WHEN fin.country_id = 24 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 THEN COALESCE(off.interest_amount, off_2.fixed_fee) * (1.125 / 100.0)                

          ELSE 0
        END AS revenue_local,

        CASE
          -- Collaboration agreement prior to 30/11/2023 (ONLY MEXICO)
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (7.0 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (2.1 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (1.05 / 100.0) * 100 / 116 / cur.usd_rate

          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (10.0 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (3.0 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date < DATE '2023-12-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (1.50 / 100.0) * 100 / 116 / cur.usd_rate

          -- Collaboration agreement prior to 01/12/2024 - 31/07/2024
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (7.0 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (2.1 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (1.050 / 100.0) * 100 / 116 / cur.usd_rate

          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (7.5 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (2.25 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (1.125 / 100.0) * 100 / 116 / cur.usd_rate

          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (5.5 / 100.0) * 100 / 119 / cur.usd_rate
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (1.65 / 100.0) * 100 / 119 / cur.usd_rate
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND lower(fin.financing_type) like('%regular%') AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) = 1 THEN fin.interest_amount * (0.825 / 100.0) * 100 / 119 / cur.usd_rate

          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND col.last_collection_date <= fin.due_date AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (6.0 / 100.0) * 100 / 119 / cur.usd_rate
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (1.80 / 100.0) * 100 / 119 / cur.usd_rate
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date BETWEEN DATE '2023-12-01' AND DATE '2024-07-31' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 AND ROW_NUMBER() OVER(PARTITION BY fin.user_id ORDER BY fin.start_date ASC) != 1 THEN fin.interest_amount * (0.9 / 100.0) * 100 / 119 / cur.usd_rate

          -- Regional collaboration agreement effective date 01/08/2024        
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND col.last_collection_date <= fin.due_date THEN fin.interest_amount * (7.5 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 THEN fin.interest_amount * (2.25 / 100.0) * 100 / 116 / cur.usd_rate
          WHEN fin.country_id = 12 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 THEN fin.interest_amount * (1.125 / 100.0) * 100 / 116 / cur.usd_rate

          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND col.last_collection_date <= fin.due_date THEN fin.interest_amount * (7.5 / 100.0) * 100 / 119 / cur.usd_rate
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 THEN fin.interest_amount * (2.25 / 100.0) * 100 / 119 / cur.usd_rate
          WHEN fin.country_id = 22 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 THEN fin.interest_amount * (1.125 / 100.0) * 100 / 119 / cur.usd_rate

          WHEN fin.country_id = 24 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND col.last_collection_date <= fin.due_date THEN COALESCE(off.interest_amount, off_2.fixed_fee) * (7.5 / 100.0) / cur.usd_rate
          WHEN fin.country_id = 24 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) >= -60 THEN COALESCE(off.interest_amount, off_2.fixed_fee) * (2.25 / 100.0) / cur.usd_rate
          WHEN fin.country_id = 24 AND fin.financing_status = 'PAID' AND (lower(fin.financing_type) like('%refill%') or lower(fin.financing_type) like('%regular%')) AND fin.start_date >= DATE '2024-08-01' AND DATE_DIFF(fin.due_date, col.last_collection_date, DAY) BETWEEN -90 AND -61 THEN COALESCE(off.interest_amount, off_2.fixed_fee) * (1.125 / 100.0) / cur.usd_rate            

          ELSE 0
        END AS revenue_usd,
        CURRENT_DATE as snap_dt_part,
        fin.parent_financing_id,
        fin.refill_amount
      FROM `indrive-neobank.core.neobank_loan` fin
      LEFT JOIN `indrive-neobank.core.agg_drivers_scoring_daily` dr ON dr.dwh_driver_id = fin.user_id
      LEFT JOIN `indrive-neobank.core.neobank_all_loan_offers` off ON off.offer_id = fin.offer_id
      LEFT JOIN `indrive-neobank.sandbox.r2_offers_historical` off_2 ON off_2.offer_id = fin.offer_id
      LEFT JOIN (
                SELECT DISTINCT
                  financing_id,
                  DATE(FIRST_VALUE(created_at) OVER(PARTITION BY financing_id ORDER BY created_at DESC)) as last_collection_date 
                FROM ( 

                      SELECT
                        financing_id, 
                        repayment_created_at AS created_at
                      FROM `indrive-neobank.core.neobank_loan_repayments`
                      WHERE project_name = 'R2'
                

                ) t1

                  ) col ON col.financing_id = fin.financing_id
      LEFT JOIN `indriver-e6e40.emart.currency_daily` cur ON CASE WHEN col.last_collection_date IS NOT NULL THEN cur.currency_dt_part = col.last_collection_date - 1 ELSE cur.currency_dt_part = fin.start_date - 1 END AND fin.country_id = cur.country_id
      WHERE 1=1
        AND fin.project_name = 'R2'