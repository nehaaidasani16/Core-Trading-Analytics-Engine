drop table if exists trade_book;

create table trade_book(
	execution_id 			varchar(15),
	portfolio_manager		varchar(40),
	instrument 				varchar(10),
	volume_units 			int,
	unit_price				decimal(12,2),
	execution_timestamp 	timestamp
);

select * from trade_book;

insert into trade_book values
('EX_101', 'Capital_Alpha', 'INFY', 4000, 1420.00, '2026-06-10 11:00:00'),
('EX_102', 'Capital_Alpha', 'INFY', 7500, 1422.50, '2026-06-10 11:01:30'),
('EX_103', 'Omega_Trust',   'RELI', 1200, 2450.00, '2026-06-10 11:02:15'),
('EX_104', 'Capital_Alpha', 'TCS',  1500, 3210.00, '2026-06-10 11:04:00'),
('EX_105', 'Omega_Trust',   'RELI', 8000, 2445.00, '2026-06-10 11:05:10'),
('O_1',    'AlphaFund',     'AAPL', 500,  150.00,  '2026-06-10 10:00:00'),
('O_2',    'AlphaFund',     'AAPL', 1200, 151.00,  '2026-06-10 10:01:00'), 
('O_3',    'BetaBank',      'MSFT', 100,  300.00,  '2026-06-20 10:02:00'),
('O_4',    'AlphaFund',     'TSLA', 300,  700.00,  '2026-06-20 10:05:00'),
('O_5',    'BetaBank',      'MSFT', 900,  299.00,  '2026-06-20 10:06:00');


-- 1) RANKING FINANCIAL RISK EXPOSURE

SELECT
	portfolio_manager,
	execution_id,
	instrument,
	(volume_units * unit_price) as total_exposure_value,
	DENSE_RANK() over (
		PARTITION BY portfolio_manager
		order by (volume_units * unit_price) desc
	) as explosure_rank
FROM trade_book;
	
-- 2) DETECTING MARKET DATA DRIFT AND GAPS

WITH linear_price_timeline as (
    SELECT
        execution_id,
        instrument,
        unit_price                        as current_execution_price,
        LAG(unit_price) OVER (
            PARTITION BY instrument
            order by execution_timestamp
        )                                 as previous_execution_price
    FROM trade_book
)

SELECT
    execution_id,
    instrument,
    current_execution_price,
    previous_execution_price,
    (current_execution_price - previous_execution_price) as absolute_price_drift
FROM linear_price_timeline
order by instrument, execution_id;


-- 3) Summary Report

SELECT
    portfolio_manager,
    execution_id,
    instrument,
    ROUND((volume_units * unit_price), 2)           as trade_exposure,
    ROUND(
        sum(volume_units * unit_price) over (
            PARTITION BY portfolio_manager
        ), 2
    )                                               as manager_total_book_size,
    ROUND(
        (volume_units * unit_price)
        /
        sum(volume_units * unit_price) over (
            PARTITION BY portfolio_manager
        ) * 100, 2
    )                                               as pct_of_manager_book,
    ROUND(
        sum(volume_units * unit_price) over (
            PARTITION BY portfolio_manager
            order by (volume_units * unit_price) DESC
        ), 2
    )                                               as running_cumulative_exposure
FROM trade_book
order by portfolio_manager, trade_exposure DESC;






