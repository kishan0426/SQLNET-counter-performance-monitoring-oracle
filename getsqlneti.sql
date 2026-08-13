SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    l_start  TIMESTAMP;
    l_end    TIMESTAMP;
    l_sec    NUMBER;

    TYPE t_counter IS TABLE OF NUMBER INDEX BY VARCHAR2(100);

    l_to_client       t_counter;
    l_from_client     t_counter;
    l_more_to_client  t_counter;
    l_more_from_client t_counter;

    l_key VARCHAR2(100);

    l_value NUMBER;

BEGIN
    ------------------------------------------------------------
    -- FIRST SNAPSHOT
    -- Only INACTIVE USER sessions
    ------------------------------------------------------------

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


    ------------------------------------------------------------
    -- START TIMER
    ------------------------------------------------------------

    l_start := SYSTIMESTAMP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'Monitoring INACTIVE sessions for 60 seconds...'
    );

    DBMS_LOCK.SLEEP(60);


    ------------------------------------------------------------
    -- END TIMER
    ------------------------------------------------------------

    l_end := SYSTIMESTAMP;

    l_sec :=
          EXTRACT(DAY FROM (l_end-l_start)) * 86400
        + EXTRACT(HOUR FROM (l_end-l_start)) * 3600
        + EXTRACT(MINUTE FROM (l_end-l_start)) * 60
        + EXTRACT(SECOND FROM (l_end-l_start));


    ------------------------------------------------------------
    -- HEADER
    ------------------------------------------------------------

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'Elapsed time: ' || ROUND(l_sec,2) || ' seconds'
    );

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        RPAD('SID',8) ||
        RPAD('SERIAL',10) ||
        RPAD('TO_CLIENT',15) ||
        RPAD('FROM_CLIENT',17) ||
        RPAD('MORE_TO',12) ||
        'MORE_FROM'
    );

    DBMS_OUTPUT.PUT_LINE(
        '------------------------------------------------------------'
    );


    ------------------------------------------------------------
    -- SECOND SNAPSHOT
    ------------------------------------------------------------

    FOR r IN (
        SELECT
            s.sid,
            s.serial#,
            s.username,
            s.machine,
            s.program,
            s.service_name,
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

        IF r.name = 'SQL*Net message to client' THEN

            l_value :=
                r.value - NVL(l_to_client(l_key), r.value);

        ELSIF r.name = 'SQL*Net message from client' THEN

            l_value :=
                r.value - NVL(l_from_client(l_key), r.value);

        ELSIF r.name = 'SQL*Net more data to client' THEN

            l_value :=
                r.value - NVL(l_more_to_client(l_key), r.value);

        ELSIF r.name = 'SQL*Net more data from client' THEN

            l_value :=
                r.value - NVL(l_more_from_client(l_key), r.value);

        END IF;

        --------------------------------------------------------
        -- Print only if counter increased
        --------------------------------------------------------

        IF l_value > 0 THEN

            DBMS_OUTPUT.PUT_LINE(
                r.sid || '  ' ||
                r.serial# || '  ' ||
                r.name || ' increased by ' ||
                l_value
            );

        END IF;

    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'Only INACTIVE sessions with increasing SQL*Net'
    );
    DBMS_OUTPUT.PUT_LINE(
        'message counters are displayed.'
    );

END;
/
