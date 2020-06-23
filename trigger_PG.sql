/*--------------------------------------------------*/
/*Permet de renseigner automatiquement la date de mise à jour de l'entité*/
CREATE OR REPLACE FUNCTION "schema_pg".trigger_set_timestamp_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.update_time = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
------
CREATE TRIGGER set_timestamp_update
BEFORE INSERT OR UPDATE ON "schema_pg".table_pg
FOR EACH ROW
EXECUTE PROCEDURE "schema_pg".trigger_set_timestamp_update();
/*--------------------------------------------------*/
/*Permet de renseigner automatiquement la date de création de l'entité*/
CREATE OR REPLACE FUNCTION "schema_pg".trigger_set_timestamp_creation()
RETURNS TRIGGER AS $$
BEGIN
  NEW.creation_time = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
------
CREATE TRIGGER set_timestamp_creation
BEFORE INSERT ON "schema_pg".table_pg
FOR EACH ROW
EXECUTE PROCEDURE "schema_pg".trigger_set_timestamp_creation();
/*--------------------------------------------------*/
/*Permet de renseigner automatiquement les coordonnées X de l'entité*/
CREATE OR REPLACE FUNCTION "schema_pg".trigger_utm28n_x()
RETURNS TRIGGER AS $$
BEGIN
  NEW.xx_utm28n = st_x(NEW.geom);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
------
CREATE TRIGGER set_utm28n_x
BEFORE INSERT OR UPDATE ON "schema_pg".table_pg
FOR EACH ROW
EXECUTE PROCEDURE "schema_pg".trigger_utm28n_x();
/*--------------------------------------------------*/
/*Permet de renseigner automatiquement les coordonnées Y de l'entité*/
CREATE OR REPLACE FUNCTION "schema_pg".trigger_utm28n_y()
RETURNS TRIGGER AS $$
BEGIN
  NEW.yy_utm28n = st_y(NEW.geom);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
------
CREATE TRIGGER set_utm28n_y
BEFORE INSERT OR UPDATE ON "schema_pg".table_pg
FOR EACH ROW
EXECUTE PROCEDURE "schema_pg".trigger_utm28n_y();
/*--------------------------------------------------*/
/*Permet de renseigner automatiquement la longitude de l'entité*/
CREATE OR REPLACE FUNCTION "schema_pg".trigger_wgs84_longitude()
RETURNS TRIGGER AS $$
BEGIN
  NEW.longitude_wgs84 = st_x(st_transform(NEW.geom,4326));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
------
CREATE TRIGGER set_wgs84_longitude
BEFORE INSERT OR UPDATE ON "schema_pg".table_pg
FOR EACH ROW
EXECUTE PROCEDURE "schema_pg".trigger_wgs84_longitude();
/*--------------------------------------------------*/
/*Permet de renseigner automatiquement la latitude de l'entité*/
CREATE OR REPLACE FUNCTION "schema_pg".trigger_wgs84_latitude()
RETURNS TRIGGER AS $$
BEGIN
  NEW.latitude_wgs84 = st_y(st_transform(NEW.geom,4326));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
------
CREATE TRIGGER set_wgs84_latitude
BEFORE INSERT OR UPDATE ON "schema_pg".table_pg
FOR EACH ROW
EXECUTE PROCEDURE "schema_pg".trigger_wgs84_latitude();
/*--------------------------------------------------*/
/*Permet de rensiegner un champ texte en fonction d'un code*/
CREATE OR REPLACE FUNCTION "schema_pg".trigger_set_list_equi_divers()
RETURNS TRIGGER AS $$
BEGIN

    IF NEW."code" = 2001
    THEN NEW."type" := 'Panneau';

    ELSIF NEW."code" = 2099
    THEN NEW."type" := 'Autre';
    END IF;

RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_list_equi_divers
BEFORE INSERT OR UPDATE ON "schema_pg".table_pg
FOR EACH ROW
EXECUTE PROCEDURE "schema_pg".trigger_set_list_equi_divers();
