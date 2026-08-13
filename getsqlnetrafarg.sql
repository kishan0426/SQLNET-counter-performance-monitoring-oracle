SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    ----------------------------------------------------------------
    -- PARAMETERS
    ----------------------------------------------------------------
    l_samples          PLS_INTEGER := 5;
    l_interval_seconds NUMBER      := 60;

    l_start            TIMESTAMP;
    l_now              TIMESTAMP;
    l_elapsed          NUMBER;

    l_to_client        NUMBER;
    l_from_client      NUMBER;
    l_more_to_client   NUMBER;
    l_more_from_client NUMBER;

BEGIN

    l_start := SYSTIMESTAMP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'Monitoring INACTIVE sessions'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Samples    : ' || l_samples
    );

    DBMS_OUTPUT.PUT_LINE(
        'Interval   : ' || l_interval_seconds || ' seconds'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Total time : ' ||
        (l_samples * l_interval_seconds) || ' seconds'
    );

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        RPAD('SAMPLE',8) ||
        RPAD('ELAPSED',12) ||
        RPAD('TO_CLIENT',15) ||
        RPAD('FROM_CLIENT',17) ||
        RPAD('MORE_TO',12) ||
        'MORE_FROM'
    );

    DBMS_OUTPUT.PUT_LINE(
        '----------------------------------------------------------------'
    );


    ----------------------------------------------------------------
    -- TAKE MULTIPLE SNAPSHOTS
    ----------------------------------------------------------------

    FOR i IN 1 .. l_samples
    LOOP

        DBMS_LOCK.SLEEP(l_interval_seconds);

        l_now := SYSTIMESTAMP;

        l_elapsed :=
              EXTRACT(DAY    FROM (l_now-l_start)) * 86400
            + EXTRACT(HOUR   FROM (l_now-l_start)) * 3600
            + EXTRACT(MINUTE FROM (l_now-l_start)) * 60
            + EXTRACT(SECOND FROM (l_now-l_start));


        ----------------------------------------------------------------
        -- SNAPSHOT OF ALL CURRENTLY INACTIVE USER SESSIONS
        ----------------------------------------------------------------

        SELECT
            NVL(SUM(
                CASE
                    WHEN sn.name = 'SQL*Net message to client'
                    THEN st.value
                END
            ),0),

            NVL(SUM(
                CASE
                    WHEN sn.name = 'SQL*Net message from client'
                    THEN st.value
                END
            ),0),

            NVL(SUM(
                CASE
                    WHEN sn.name = 'SQL*Net more data to client'
                    THEN st.value
                END
            ),0),

            NVL(SUM(
                CASE
                    WHEN sn.name = 'SQL*Net more data from client'
                    THEN st.value
                END
            ),0)

        INTO
            l_to_client,
            l_from_client,
            l_more_to_client,
            l_more_from_client

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
          );


        ----------------------------------------------------------------
        -- PRINT SAMPLE
        ----------------------------------------------------------------

        DBMS_OUTPUT.PUT_LINE(
            RPAD(i,8) ||
            RPAD(ROUND(l_elapsed,1),12) ||
            RPAD(l_to_client,15) ||
            RPAD(l_from_client,17) ||
            RPAD(l_more_to_client,12) ||
            l_more_from_client
        );

    END LOOP;


    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'Completed ' || l_samples ||
        ' snapshots over approximately ' ||
        ROUND(l_elapsed,1) || ' seconds.'
    );

END;
/
