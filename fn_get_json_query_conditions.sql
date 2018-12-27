-- -----------------------------------------------------
-- function fn_get_json_query_conditions
-- -----------------------------------------------------

DROP function IF EXISTS `fn_get_json_query_conditions`;

DELIMITER $$
CREATE FUNCTION `fn_get_json_query_conditions`(
  i_conditions   JSON,
  i_table_alias  VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin,
  i_column_map   JSON
) RETURNS        LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin
BEGIN
/**
  Parsing query conditions from JSON (subroutine of sp_json_get_query_conditions) 
  2018-10 Aiden Kihyun Kim
**/

  DECLARE v_cnt1         INT DEFAULT 0;
  DECLARE v_cnt2         INT DEFAULT 0;
  DECLARE v_column       VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_type         VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL;
  DECLARE v_array        JSON DEFAULT NULL;
  DECLARE v_conditions   LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT '';
  DECLARE v_table_alias  VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT '';

  IF (i_conditions IS NOT NULL) AND JSON_VALID(i_conditions) AND (JSON_TYPE(i_conditions) = 'OBJECT') THEN

    IF (i_table_alias IS NOT NULL) AND (LENGTH(i_table_alias) > 0) THEN
      SET v_table_alias = CONCAT('`', i_table_alias, '`.');
    END IF;
  
    WHILE (v_cnt1 < JSON_LENGTH(i_conditions)) DO
    
      IF (LENGTH(v_conditions) > 0) THEN
        SET v_conditions = CONCAT(v_conditions, ' AND ');
      END IF;
      SET v_column = JSON_UNQUOTE(JSON_EXTRACT(JSON_KEYS(i_conditions),CONCAT('$[',v_cnt1,']')));
      SET v_type = JSON_TYPE(JSON_EXTRACT(i_conditions,CONCAT('$.',v_column)));
      
      IF (i_column_map IS NULL) OR JSON_CONTAINS_PATH(i_column_map,'one',CONCAT('$.',v_column)) THEN
        IF v_type = 'NULL' THEN
          SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '` IS NULL');
        ELSEIF v_type IN ('INTEGER','DOUBLE','DECIMAL','BIT') THEN
          SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '`=', JSON_EXTRACT(i_conditions, CONCAT('$.',v_column)));
        ELSEIF v_type IN ('ARRAY','OBJECT') THEN
          SET v_array = JSON_EXTRACT(i_conditions,CONCAT('$.',v_column));
          IF v_type = 'OBJECT' THEN
            IF JSON_CONTAINS_PATH(v_array,'one',CONCAT('$."2"')) THEN
              SET v_array = JSON_ARRAY(JSON_EXTRACT(v_array,'$."0"'),JSON_EXTRACT(v_array,'$."1"'),JSON_EXTRACT(v_array,'$."2"'));
            ELSE
              SET v_array = JSON_ARRAY(JSON_EXTRACT(v_array,'$."0"'),JSON_EXTRACT(v_array,'$."1"'));
            END IF;
          END IF;
          IF UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]'))) = '<>' THEN
            IF JSON_TYPE(JSON_EXTRACT(v_array,'$[1]')) IN ('INTEGER','DOUBLE','DECIMAL','BIT') THEN
              SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '`<>', JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[1]')));
            ELSE
              SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '`<>''', REPLACE(JSON_UNQUOTE(JSON_EXTRACT(v_array, '$[1]')),'''',''''''), '''');
            END IF;
          ELSEIF UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]'))) = 'BETWEEN' THEN
            SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '` BETWEEN ', JSON_EXTRACT(v_array,'$[1]'), ' AND ', JSON_EXTRACT(v_array,'$[2]'));
          ELSEIF JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]')) IN ('<','<=','>','>=') THEN
            SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '`', JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]')), JSON_EXTRACT(v_array,'$[1]'));
          ELSEIF UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]'))) = 'LIKE' THEN
            SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '` LIKE ''', REPLACE(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[1]')),'''',''''''), '''');
          ELSEIF UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]'))) = 'IN' AND JSON_TYPE(JSON_EXTRACT(v_array,'$[1]')) = 'ARRAY' THEN
            SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '` IN ('), v_cnt2=0;
            WHILE (v_cnt2 < JSON_LENGTH(JSON_EXTRACT(v_array,'$[1]'))) DO
              IF (v_cnt2 > 0) THEN
                SET v_conditions = CONCAT(v_conditions, ',');
              END IF;
              IF JSON_TYPE(JSON_EXTRACT(v_array,CONCAT('$[1][',v_cnt2,']'))) IN ('INTEGER','DOUBLE','DECIMAL','BIT') THEN
                SET v_conditions = CONCAT(v_conditions, JSON_UNQUOTE(JSON_EXTRACT(v_array,CONCAT('$[1][',v_cnt2,']'))));
              ELSE
                SET v_conditions = CONCAT(v_conditions, '''', REPLACE(JSON_UNQUOTE(JSON_EXTRACT(v_array, CONCAT('$[1][',v_cnt2,']'))),'''',''''''), '''');
              END IF;
              SET v_cnt2 = v_cnt2 + 1;
            END WHILE;
            SET v_conditions = CONCAT(v_conditions, ')');
          ELSEIF UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]'))) = 'NOT_IN' AND JSON_TYPE(JSON_EXTRACT(v_array,'$[1]')) = 'ARRAY' THEN
            SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '` NOT IN ('), v_cnt2=0;
            WHILE (v_cnt2 < JSON_LENGTH(JSON_EXTRACT(v_array,'$[1]'))) DO
              IF (v_cnt2 > 0) THEN
                SET v_conditions = CONCAT(v_conditions, ',');
              END IF;
              IF JSON_TYPE(JSON_EXTRACT(v_array,CONCAT('$[1][',v_cnt2,']'))) IN ('INTEGER','DOUBLE','DECIMAL','BIT') THEN
                SET v_conditions = CONCAT(v_conditions, JSON_UNQUOTE(JSON_EXTRACT(v_array,CONCAT('$[1][',v_cnt2,']'))));
              ELSE
                SET v_conditions = CONCAT(v_conditions, '''', REPLACE(JSON_UNQUOTE(JSON_EXTRACT(v_array, CONCAT('$[1][',v_cnt2,']'))),'''',''''''), '''');
              END IF;
              SET v_cnt2 = v_cnt2 + 1;
            END WHILE;
            SET v_conditions = CONCAT(v_conditions, ')');
          ELSEIF UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]'))) = 'IS' THEN
            SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '` IS ', JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[1]')));
          ELSEIF UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]'))) = 'IS_NOT' THEN
            SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '` IS NOT ', JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[1]')));
          ELSEIF UPPER(JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[0]'))) = 'MATCH' THEN
            SET v_conditions = CONCAT(v_conditions, 'MATCH (',v_table_alias,'`', v_column, '`) AGAINST (''"', JSON_UNQUOTE(JSON_EXTRACT(v_array,'$[1]')), '"'' IN BOOLEAN MODE)' );
          END IF;
        ELSE
          SET v_conditions = CONCAT(v_conditions, v_table_alias, '`', v_column, '`=''', REPLACE(JSON_UNQUOTE(JSON_EXTRACT(i_conditions, CONCAT('$.',v_column))),'''',''''''), '''');
        END IF;
      END IF;
          
      SET v_cnt1 = v_cnt1 + 1;
    END WHILE;
    
  END IF;
  
  RETURN v_conditions;

END$$

DELIMITER ;