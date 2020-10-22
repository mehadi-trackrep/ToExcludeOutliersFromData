select source, percentile_disc(0.75) within group (order by amount)  ---discrete percentile for getting result from input data points
from transactions group by source;

select source, percentile_cont(0.75) within group (order by amount)  ---continuous percentile for getting result from interpolation/approximation
from transactions group by source;

--CTE = Common Table Expression ('WITH')

--FIVE NUMBER SUMMARIES COMMAND:-
WITH quartiles AS (
SELECT source,
	   MIN(amount) as minimum,
       PERCENTILE_CONT(0.25) WITHIN GROUP 
         (ORDER BY amount) AS q1,
       PERCENTILE_CONT(0.5) WITHIN GROUP 
         (ORDER BY amount) AS median,
       PERCENTILE_CONT(0.75) WITHIN GROUP 
         (ORDER BY amount) AS q3,
	   MAX(amount) as maximum
  FROM transactions group by source
)
select * from quartiles



-- To use "1.5*IQR" rule to find outliers, the minimum and maximum is the whisker (boundary of of the 1.5*IQR rule)
-- OUTLIER DETECTON COMMAND - using "1.5*IQR" rule & Box-plot with whisker approach:-
WITH details AS(   --sort rows
	SELECT source, amount,
	ROW_NUMBER() OVER(PARTITION BY source ORDER BY amount) AS row_number,
	SUM(1) OVER(PARTITION BY source) AS total
	FROM transactions
   ), quartiles AS(
	SELECT source, amount,
	AVG(CASE  --Averaging from different types of range value (w.r.to ranking(row_number) ) like lowest - q1, q1-q2, q2-q3, q3-highest
 		WHEN ROW_NUMBER >= (FLOOR(total/2.0)/2.0) AND row_number <= (FLOOR(total/2.0)/2.0) + 1
 		THEN amount/1.0 ELSE NULL END  --ELSE null means: no statement to execute, we can drop this portion
 	   ) OVER(PARTITION BY source) AS q1,
 	AVG(CASE  
 		WHEN ROW_NUMBER >= (FLOOR(total/2.0)) AND row_number <= (FLOOR(total/2.0)) + 1
 		THEN amount/1.0 ELSE NULL END
 	   ) OVER(PARTITION BY source) AS median,
 	AVG(CASE  
 		WHEN ROW_NUMBER >= (CEIL(total/2.0) + FLOOR(total/2.0)/2.0) AND row_number <= (CEIL(total/2.0) + FLOOR(total/2.0)/2.0) + 1
 		THEN amount ELSE NULL END
 	   ) OVER(PARTITION BY source) AS q3
 	FROM details
 ) SELECT source,   ---use 1.5*IQR rule to find outliers, the minimum and maximum is the whisker (boundary of of the 1.5*IQR rule)
 	ARRAY_TO_STRING(ARRAY_AGG(CASE WHEN amount < q1 - ((q3-q1) * 1.5) 
          THEN amount::VARCHAR ELSE NULL END),',') AS lower_outliers,
        MIN(CASE WHEN amount >= q1 - ((q3-q1) * 1.5) THEN amount ELSE NULL END) AS minimum,
        AVG(q1) AS q1,
        AVG(median) AS median,
        AVG(q3) AS q3,
        MAX(CASE WHEN amount <= q3 + ((q3-q1) * 2) THEN amount ELSE NULL END) AS maximum, ---As, the distribution is right skewed, so we can extende the right boundary/limit
        ARRAY_TO_STRING(ARRAY_AGG(CASE WHEN amount > q3 + ((q3-q1) * 2) 
          THEN amount::VARCHAR ELSE NULL END),',') AS upper_outliers
   FROM quartiles
 GROUP BY 1