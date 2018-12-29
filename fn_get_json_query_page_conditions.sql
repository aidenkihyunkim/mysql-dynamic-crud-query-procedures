-- -----------------------------------------------------
-- function fn_get_json_query_page_conditions
-- -----------------------------------------------------

DROP function IF EXISTS `fn_get_json_query_page_conditions`;

DELIMITER $$
CREATE FUNCTION `fn_get_json_query_page_conditions`(
  i_conditions    JSON,
  i_allow_pageby  TINYINT
) RETURNS         LONGTEXT CHARSET utf8mb4 COLLATE utf8mb4_bin
BEGIN
/**
  Parsing paging query conditions from JSON
  2018-10 Aiden Kihyun Kim
**/

  DECLARE v_limit_column  VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT '_LIMIT_BY';
  DECLARE v_page_column   VARCHAR(64) CHARSET utf8mb4 COLLATE utf8mb4_bin DEFAULT '_PAGE_BY';
  DECLARE v_pages         JSON DEFAULT NULL;

  IF JSON_VALID(i_conditions) THEN

    IF JSON_CONTAINS_PATH(i_conditions,'one',CONCAT('$.',v_limit_column)) THEN
      SET v_pages = JSON_EXTRACT(i_conditions,CONCAT('$.',v_limit_column));
    ELSEIF JSON_CONTAINS_PATH(i_conditions,'one', CONCAT('$[*].',v_limit_column)) THEN
      SET v_pages = JSON_EXTRACT(i_conditions,CONCAT('$[*].',v_limit_column));
      IF (JSON_TYPE(v_pages) = 'ARRAY') THEN
        SET v_pages = JSON_EXTRACT(JSON_EXTRACT(i_conditions,CONCAT('$[*].',v_limit_column)),'$[0]');
      END IF;
    END IF;
    IF (v_pages IS NOT NULL) THEN
      IF (JSON_TYPE(v_pages) = 'ARRAY') THEN
        IF (JSON_LENGTH(v_pages) = 1) THEN
          RETURN CAST(JSON_UNQUOTE(JSON_EXTRACT(v_pages,'$[0]')) AS CHAR);
        ELSE
          RETURN CONCAT(JSON_UNQUOTE(JSON_EXTRACT(v_pages,'$[0]')), ',', JSON_UNQUOTE(JSON_EXTRACT(v_pages,'$[1]')));
        END IF;
      ELSE
        RETURN CAST(JSON_UNQUOTE(v_pages) AS CHAR);
      END IF;
    END IF;

    IF (i_allow_pageby > 0) THEN
      IF JSON_CONTAINS_PATH(i_conditions,'one',CONCAT('$.',v_page_column)) THEN
        SET v_pages = JSON_EXTRACT(i_conditions,CONCAT('$.',v_page_column));
      ELSEIF JSON_CONTAINS_PATH(i_conditions,'one', CONCAT('$[*].',v_page_column)) THEN
        SET v_pages = JSON_EXTRACT(i_conditions,CONCAT('$[*].',v_page_column));
        IF (JSON_TYPE(v_pages) = 'ARRAY') THEN
          SET v_pages = JSON_EXTRACT(JSON_EXTRACT(i_conditions,CONCAT('$[*].',v_page_column)),'$[0]');
        END IF;
      END IF;
      IF (v_pages IS NOT NULL) AND (JSON_TYPE(v_pages) = 'ARRAY') THEN
        RETURN CONCAT(((CAST(JSON_EXTRACT(v_pages,'$[0]') AS UNSIGNED)-1)*CAST(JSON_EXTRACT(v_pages,'$[1]') AS UNSIGNED)), ',', JSON_UNQUOTE(JSON_EXTRACT(v_pages,'$[1]')));
      END IF;
    END IF;

  END IF;
  
  RETURN '';

END$$

DELIMITER ;