/*--------------------------------------------------*/
/*Vues*/

SELECT *
FROM pg_views t
WHERE t.viewowner != 'u_vitis';
/*--------------------------------------------------*/
/*Tables*/

SELECT *
FROM pg_tables t
WHERE t.tableowner != 'u_vitis';
/*--------------------------------------------------*/
