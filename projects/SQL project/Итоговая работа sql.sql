1. Выведите название самолетов, которые имеют менее 50 посадочных мест?

SELECT a.aircraft_code,a.model, count(s.seat_no) AS seats  
FROM aircrafts a 
JOIN seats s  ON s.aircraft_code = a.aircraft_code 
GROUP BY a.aircraft_code
HAVING count(s.seat_no) < 50

2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.


SELECT date_trunc('month',book_date)::date Дата,
round (((sum(total_amount)-LAG(sum(total_amount),1,0) OVER (ORDER BY date_trunc('month',book_date)::date))/
LAG(sum(total_amount)) OVER (ORDER BY date_trunc('month',book_date)::date))*100,2) "Процентное изменение"
FROM bookings b 
GROUP BY 1



3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.


SELECT model
FROM (SELECT aircraft_code , array_agg(fare_conditions)
FROM seats s 
GROUP BY aircraft_code 
HAVING 'Business'!=ALL(array_agg(fare_conditions))) s
JOIN aircrafts a ON a.aircraft_code = s.aircraft_code


4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, 
учитывая только те самолеты, которые летали пустыми и только те дни, 
где из одного аэропорта таких самолетов вылетало более одного.
В результате должны быть код аэропорта, дата, 
количество пустых мест в самолете и накопительный итог.


with cte AS (SELECT f.flight_id ,f.actual_departure::date,departure_airport,aircraft_code
,count(*) OVER (PARTITION BY f.actual_departure::date,departure_airport)
FROM flights f 
LEFT JOIN boarding_passes bp ON bp.flight_id = f.flight_id  
WHERE bp.flight_id IS NULL AND f.actual_departure IS NOT null
GROUP BY f.flight_id ,f.actual_departure,departure_airport),
cte_1 AS(SELECT a.aircraft_code a_code,count(s.seat_no) count_s  
FROM aircrafts a 
JOIN seats s  ON s.aircraft_code = a.aircraft_code 
GROUP BY a.aircraft_code),
cte_2 AS (SELECT * FROM cte JOIN cte_1 ON cte.aircraft_code=a_code
WHERE count>1)
SELECT departure_airport "Код аэропорта",actual_departure::date Дата, count_s "Кол-во пустых мест",
sum(count_s) OVER (PARTITION BY departure_airport,actual_departure::date ORDER BY actual_departure::date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) 
AS "Нарастающий итог"
FROM cte_2



 5.Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
 Выведите в результат названия аэропортов и процентное отношение.
 Решение должно быть через оконную функцию.
 

SELECT dan "Аэропорт вылета", aan "Аэропорт прилета",count_r*100/sum(count_r) OVER () "процентное отношение"
FROM 
(SELECT departure_airport_name dan ,arrival_airport_name aan,count(*) AS count_r
FROM flights_v fv 
GROUP BY departure_airport_name  ,arrival_airport_name)



6. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7


SELECT  substring(contact_data ->>'phone',3,3) "Код оператора",count(contact_data ->>'phone') AS "Количество пассажиров"
FROM tickets t 
GROUP BY substring(contact_data ->>'phone',3,3)


7. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
 До 50 млн - low
 От 50 млн включительно до 150 млн - middle
 От 150 млн включительно - high
 Выведите в результат количество маршрутов в каждом полученном классе
 
  

SELECT some_case,count(*)
FROM
(SELECT count(*),CASE 
				WHEN sum(tf.amount)< 50000000 THEN 'low'
				WHEN sum(tf.amount) >= 50000000 AND sum(tf.amount) <150000000 THEN 'middle'
				ELSE 'high'
END some_case
FROM ticket_flights tf  JOIN flights f  ON tf.flight_id = f.flight_id 
GROUP BY f.departure_airport ,f.arrival_airport)
GROUP BY some_case
  
 
 8. Вычислите медиану стоимости перелетов, медиану размера бронирования и 
 отношение медианы бронирования к медиане стоимости перелетов, округленной до сотых
 

WITH cte AS (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tf.amount) p_1
FROM ticket_flights tf ),
cte_1 AS (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount) p_2
FROM bookings b )
SELECT p_1 "медиана стоимости перелетов",
p_2 "медиана размера бронирования",
round((p_2/p_1)::numeric,2) "отношение медиан"
FROM cte,cte_1
WHERE p_1!=p_2



 9. Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно найти расстояние между аэропортами 
  и с учетом стоимости перелетов получить искомый результат
  Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
  Для работы модуля earthdistance необходимо предварительно установить модуль cube.
  Установка модулей происходит через команду: create extension название_модуля.

  create EXTENSION cube
  
  create EXTENSION earthdistance
  
WITH cte AS (SELECT  f_id,
round(earth_distance(ll_to_earth(lati_d,long_d),ll_to_earth(lati_a,long_a))/1000) AS dis,
a_name da,a2_name aa
FROM 
(SELECT f.flight_id f_id,a.longitude long_d,a.latitude lati_d,
a2.longitude long_a,a2.latitude lati_a, a.airport_name a_name, a2.airport_name a2_name
FROM flights f 
JOIN airports a ON a.airport_code = f.departure_airport 
JOIN airports a2 ON a2.airport_code = f.arrival_airport)),
cte_2 AS (SELECT flight_id f_id2,min(amount) m_amount
FROM ticket_flights
GROUP BY flight_id)
SELECT min(round(m_amount/dis::numeric,2)),
da "Аэропорт вылета",aa "Аэропорт прилета"
FROM cte
JOIN cte_2 ON cte.f_id = cte_2.f_id2
GROUP BY da,aa
ORDER BY 1
FETCH FIRST 1 ROWS WITH ties


