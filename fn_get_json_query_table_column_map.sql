-- -----------------------------------------------------
-- function fn_get_json_query_table_column_map
-- -----------------------------------------------------

DROP function IF EXISTS `fn_get_json_query_table_column_map`;

DELIMITER $$
CREATE FUNCTION `fn_get_json_query_table_column_map`(
  i_table   VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin,
  i_schema  VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin
) RETURNS   JSON
BEGIN
/**
  Getting table columns information from INFORMATION_SCHEMA
  2018-10 Aiden Kihyun Kim
**/

  DECLARE v_schema      VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_column_map  JSON DEFAULT NULL;
  DECLARE v_group_concat_max_len  INT DEFAULT 1024;

  SET v_group_concat_max_len = @@group_concat_max_len;
  IF (v_group_concat_max_len < 10240) THEN
    SET @@group_concat_max_len = 10240;
  END IF;
  
  SET v_schema = IF(i_schema IS NULL, DATABASE(), i_schema);
  SELECT CAST( (CONCAT('{', GROUP_CONCAT(CONCAT('"',COLUMN_NAME,'":"',DATA_TYPE,'"')), '}')) AS JSON) INTO v_column_map
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = v_schema AND TABLE_NAME = i_table ORDER BY ORDINAL_POSITION;

  SET @@group_concat_max_len = v_group_concat_max_len;
  
  RETURN v_column_map;

END$$

DELIMITER ;