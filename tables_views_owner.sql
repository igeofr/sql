/*--------------------------------------------------*/
/*Vues*/

SELECT *
FROM pg_views t
WHERE t.viewowner != 'toto';
/*--------------------------------------------------*/
/*Tables*/

SELECT *
FROM pg_tables t
WHERE t.tableowner != 'toto';
/*--------------------------------------------------*/
