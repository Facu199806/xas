# Oracle 23c Free 23.3 - notas de compatibilidad

## SQL/JSON dentro de PL/SQL

En la VM Oracle Database 23c Free 23.3.0.23.09 se observó `PLS-00684: tipo de datos no válido para el valor de retorno de JSON` al usar `JSON_OBJECT(... RETURNING CLOB)` como expresión PL/SQL directa, por ejemplo en un `RETURN` o una asignación `:=`.

Para mantener compatibilidad con esta build, NOXAS genera esos CLOB JSON dentro de contexto SQL:

```sql
SELECT JSON_OBJECT(... RETURNING CLOB)
  INTO l_payload
  FROM dual;
```

Las funciones SQL/JSON usadas dentro de sentencias SQL, como `SELECT`, `INSERT ... VALUES` y `JSON_ARRAYAGG`, se mantienen en contexto SQL.

Esta nota documenta el comportamiento validado en el laboratorio local y evita reintroducir el patrón incompatible en scripts futuros.
