SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    ----------------------------------------------------------------
    -- CHANGE THIS VALUE
    ----------------------------------------------------------------
    l_interval_seconds NUMBER := 30;

    l_start  TIMESTAMP;
    l_end    TIMESTAMP;
    l_sec    NUMBER;

    TYPE t_counter IS TABLE OF NUMBER INDEX BY VARCHAR2(100);

    l_to_client        t_counter;
    l_from_client      t_counter;
    l_more_to_client   t_counter;
    l_more_from_client t_counter;

    l_key   VARCHAR2(100);
    l_value NUMBER;

BEGIN
    ----------------------------------------------------------------
    -- SNAPSHOT 1
    -- Only USER sessions currently INACTIVE
    ----------------------------------------------------------------

    FOR r IN (
        SELECT
            s.sid,
            s.serial#,
            sn.name,
            st.value
        FROM v$session s
        JOIN v$sesstat st
          ON st.sid = s.sid
        JOIN v$statname sn
          ON sn.statistic# = st.statistic#
        WHERE s.type = 'USER'
          AND s.status = 'INACTIVE'
          AND sn.name IN (
              'SQL*Net message to client',
              'SQL*Net message from client',
              'SQL*Net more data to client',
              'SQL*Net more data from client'
          )
    )
    LOOP
        l_key := r.sid || ':' || r.serial#;

        CASE r.name
            WHEN 'SQL*Net message to client' THEN
                l_to_client(l_key) := r.value;

            WHEN 'SQL*Net message from client' THEN
                l_from_client(l_key) := r.value;

            WHEN 'SQL*Net more data to client' THEN
                l_more_to_client(l_key) := r.value;

            WHEN 'SQL*Net more data from client' THEN
                l_more_from_client(l_key) := r.value;
        END CASE;
    END LOOP;


    ----------------------------------------------------------------
    -- WAIT
    ----------------------------------------------------------------

    l_start := SYSTIMESTAMP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'Taking SQL*Net snapshot for ' ||
        l_interval_seconds ||
        ' seconds...'
    );

    DBMS_LOCK.SLEEP(l_interval_seconds);

    l_end := SYSTIMESTAMP;


    ----------------------------------------------------------------
    -- ACTUAL ELAPSED TIME
    ----------------------------------------------------------------

    l_sec :=
          EXTRACT(DAY    FROM (l_end-l_start)) * 86400
        + EXTRACT(HOUR   FROM (l_end-l_start)) * 3600
        + EXTRACT(MINUTE FROM (l_end-l_start)) * 60
        + EXTRACT(SECOND FROM (l_end-l_start));


    ----------------------------------------------------------------
    -- HEADER
    ----------------------------------------------------------------

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'Actual elapsed time: ' || ROUND(l_sec,2) || ' seconds'
    );

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'SID    SERIAL    COUNTER                         DELTA'
    );
    DBMS_OUTPUT.PUT_LINE(
        '----------------------------------------------------------'
    );


    ----------------------------------------------------------------
    -- SNAPSHOT 2
    ----------------------------------------------------------------

    FOR r IN (
        SELECT
            s.sid,
            s.serial#,
            sn.name,
            st.value
        FROM v$session s
        JOIN v$sesstat st
          ON st.sid = s.sid
        JOIN v$statname sn
          ON sn.statistic# = st.statistic#
        WHERE s.machine like '%pd03ams-bat-23%'
          AND s.status = 'INACTIVE'
          AND sn.name IN (
              'SQL*Net message to client',
              'SQL*Net message from client',
              'SQL*Net more data to client',
              'SQL*Net more data from client'
          )
        ORDER BY s.sid, sn.name
    )
    LOOP

        l_key := r.sid || ':' || r.serial#;

        IF r.name = 'SQL*Net message to client' THEN

            l_value :=
                r.value - NVL(l_to_client(l_key), r.value);

        ELSIF r.name = 'SQL*Net message from client' THEN

            l_value :=
                r.value - NVL(l_from_client(l_key), r.value);

        ELSIF r.name = 'SQL*Net more data to client' THEN

            l_value :=
                r.value - NVL(l_more_to_client(l_key), r.value);

        ELSE

            l_value :=
                r.value - NVL(l_more_from_client(l_key), r.value);

        END IF;


        ----------------------------------------------------------------
        -- ONLY SHOW COUNTERS THAT INCREASED
        ----------------------------------------------------------------

        IF l_value > 0 THEN

            DBMS_OUTPUT.PUT_LINE(
                RPAD(r.sid,8) ||
                RPAD(r.serial#,10) ||
                RPAD(r.name,35) ||
                l_value
            );

        END IF;

    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'Only INACTIVE sessions with increasing counters are shown.'
    );

END;
/
