-- -----------------------------------------------------
-- procedure sp_json_insert_table
-- -----------------------------------------------------

DROP procedure IF EXISTS `sp_json_insert_table`;

DELIMITER $$
CREATE PROCEDURE `sp_json_insert_table`(
  IN   i_table           VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin,
  IN   i_columns         JSON,
  IN   i_schema          VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin,
  OUT  o_return          INT,
  OUT  o_row_count       INT,
  OUT  o_last_insert_id  BIGINT
)
body:BEGIN
/**
  General procedure for inserting a table row from JSON
  2018-10 Aiden Kihyun Kim
  
  Parameters
    IN   i_table           VARCHAR(64)  : Table name
    IN   i_columns         JSON         : Columns {"col1_name":col1_value, "col2_name":"col2_value", ... }
    IN   i_schema          VARCHAR(64)  : Database name
    OUT  o_return          INT          : Return code (0=success)
    OUT  o_row_count       INT          : Value of ROW_COUNT()
    OUT  o_last_insert_id  BIGINT       : Value of LAST_INSERT_ID()
**/
  
  DECLARE v_autocommit      BIT DEFAULT @@AUTOCOMMIT;
  DECLARE v_schema          VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE c_done            BIT DEFAULT FALSE;
  DECLARE v_column          VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_column_key      VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_extra           VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_type            VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_query1          LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_query2          LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE require_rollback  CONDITION FOR SQLSTATE '45000';
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
    SET o_return = -999, o_row_count = 0, o_last_insert_id = NULL; IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  DECLARE EXIT HANDLER FOR 1062 BEGIN 
    SET o_return = -901, o_row_count = 0, o_last_insert_id = NULL; IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  DECLARE EXIT HANDLER FOR 1216,1452 BEGIN 
    SET o_return = -902, o_row_count = 0, o_last_insert_id = NULL; IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  DECLARE EXIT HANDLER FOR 1217,1451 BEGIN 
    SET o_return = -903, o_row_count = 0, o_last_insert_id = NULL; IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  DECLARE EXIT HANDLER FOR require_rollback BEGIN
    IF (v_autocommit=1) AND (@@AUTOCOMMIT=0) THEN ROLLBACK; SET SESSION autocommit = 1; END IF;
  END;
  
  SET o_return = -1, o_row_count = 0, o_last_insert_id = NULL;
  
  SET v_schema = IF(i_schema IS NULL, DATABASE(), v_schema);
  
  BEGIN
    DECLARE c_column CURSOR FOR 
      SELECT COLUMN_NAME, COLUMN_KEY, EXTRA FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA=v_schema AND TABLE_NAME=i_table AND EXTRA<>'VIRTUAL GENERATED' ORDER BY ORDINAL_POSITION;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET c_done = TRUE;
    
    OPEN c_column;
    cursor_loop: LOOP
      FETCH c_column INTO v_column, v_column_key, v_extra;
      IF c_done THEN
        LEAVE cursor_loop;
      END IF;
      IF (v_column_key='PRI' AND v_extra='auto_increment') THEN
        SET o_last_insert_id = NULL;
      ELSEIF JSON_CONTAINS_PATH(i_columns,'one',CONCAT('$.',v_column)) THEN
        SET v_query1 = CONCAT(IF(v_query1 IS NULL,'',CONCAT(v_query1,', ')), '`', v_column, '`');
        SET v_query2 = IF(v_query2 IS NULL,'',CONCAT(v_query2,', '));
        SET v_type = JSON_TYPE(JSON_EXTRACT(i_columns,CONCAT('$.',v_column)));
        IF v_type='NULL' THEN
          SET v_query2 = CONCAT(v_query2, 'NULL');
        ELSEIF v_type IN ('INTEGER','DOUBLE','DECIMAL','BIT') THEN
          SET v_query2 = CONCAT(v_query2, JSON_EXTRACT(i_columns, CONCAT('$.',v_column)));
        ELSE
          SET v_query2 = CONCAT(v_query2, '''', REPLACE(JSON_UNQUOTE(JSON_EXTRACT(i_columns, CONCAT('$.',v_column))),'''',''''''), '''');
        END IF;
      END IF;
    END LOOP;
    
    CLOSE c_column;
  END;
  
  IF (v_query1 IS NULL) THEN
    SET o_return = -101, o_row_count = 0;
    SIGNAL require_rollback;
  END IF;
  IF (v_query2 IS NULL) THEN
    SET o_return = -102, o_row_count = 0;
    SIGNAL require_rollback;
  END IF;
  
  IF (v_autocommit = 1) THEN
    SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SET SESSION autocommit = 0;
    START TRANSACTION;
  END IF;
  
  SET @query = CONCAT('INSERT INTO `', v_schema, '`.`', i_table, '` (', v_query1, ') VALUES (', v_query2, ')');
  PREPARE stmt FROM @query;
  EXECUTE stmt;
  SELECT ROW_COUNT(), LAST_INSERT_ID() INTO @row_count, @last_insert_id;
  DEALLOCATE PREPARE stmt;
  
  IF (v_autocommit = 1) AND (@@AUTOCOMMIT = 0) THEN
    COMMIT;
    SET SESSION autocommit = 1;
  END IF;
  
  SET o_return = 0, o_row_count = @row_count, o_last_insert_id = @last_insert_id;
  
END$$

DELIMITER ;