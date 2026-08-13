SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    ----------------------------------------------------------------
    -- PARAMETERS
    ----------------------------------------------------------------
    l_samples          PLS_INTEGER := 5;
    l_interval_seconds NUMBER      := 15;

    l_start            TIMESTAMP;
    l_now              TIMESTAMP;
    l_elapsed          NUMBER;

    l_sent             NUMBER;
    l_received         NUMBER;

    l_sent_prev        NUMBER := 0;
    l_received_prev    NUMBER := 0;

    l_sent_delta       NUMBER;
    l_received_delta   NUMBER;

    l_first_sample     BOOLEAN := TRUE;

BEGIN

    l_start := SYSTIMESTAMP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE(' INACTIVE SESSION SQL*NET TRAFFIC MONITOR');
    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        'Samples    : ' || l_samples
    );

    DBMS_OUTPUT.PUT_LINE(
        'Interval   : ' || l_interval_seconds || ' seconds'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Total time : approximately ' ||
        (l_samples * l_interval_seconds) || ' seconds'
    );

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        RPAD('SAMPLE',8) ||
        RPAD('ELAPSED',12) ||
        RPAD('SENT_MB',15) ||
        RPAD('RECV_MB',15) ||
        RPAD('TOTAL_MB',15) ||
        'TOTAL_MBPS'
    );

    DBMS_OUTPUT.PUT_LINE(
        '---------------------------------------------------------------------'
    );


    ----------------------------------------------------------------
    -- MULTIPLE SNAPSHOTS
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
        -- CURRENT TOTAL BYTES FOR INACTIVE USER SESSIONS
        ----------------------------------------------------------------

        SELECT
            NVL(SUM(
                CASE
                    WHEN sn.name =
                        'bytes sent via SQL*Net to client'
                    THEN st.value
                END
            ),0),

            NVL(SUM(
                CASE
                    WHEN sn.name =
                        'bytes received via SQL*Net from client'
                    THEN st.value
                END
            ),0)

        INTO
            l_sent,
            l_received

        FROM v$session s
        JOIN v$sesstat st
          ON st.sid = s.sid
        JOIN v$statname sn
          ON sn.statistic# = st.statistic#

        WHERE s.type = 'USER'
          AND s.status = 'INACTIVE'
          AND sn.name IN (
              'bytes sent via SQL*Net to client',
              'bytes received via SQL*Net from client'
          );


        ----------------------------------------------------------------
        -- FIRST SAMPLE
        ----------------------------------------------------------------

        IF l_first_sample THEN

            l_sent_delta     := 0;
            l_received_delta := 0;

            l_first_sample := FALSE;

        ELSE

            l_sent_delta :=
                GREATEST(l_sent - l_sent_prev, 0);

            l_received_delta :=
                GREATEST(l_received - l_received_prev, 0);

        END IF;


        ----------------------------------------------------------------
        -- SAVE CURRENT SNAPSHOT
        ----------------------------------------------------------------

        l_sent_prev     := l_sent;
        l_received_prev := l_received;


        ----------------------------------------------------------------
        -- OUTPUT
        ----------------------------------------------------------------

        DBMS_OUTPUT.PUT_LINE(
            RPAD(i,8) ||
            RPAD(ROUND(l_elapsed,1),12) ||
            RPAD(
                ROUND(l_sent_delta / 1024 / 1024,2),
                15
            ) ||
            RPAD(
                ROUND(l_received_delta / 1024 / 1024,2),
                15
            ) ||
            RPAD(
                ROUND(
                    (l_sent_delta + l_received_delta)
                    / 1024 / 1024,
                    2
                ),
                15
            ) ||
            ROUND(
                (
                    (l_sent_delta + l_received_delta)
                    / 1024 / 1024
                )
                / l_interval_seconds
                * 8,
                2
            )
        );

    END LOOP;


    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(
        'TOTAL_MBPS = SQL*Net traffic generated during each interval'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Only sessions that were INACTIVE at each snapshot are included.'
    );

END;
/
