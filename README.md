# bda-mundial-2026

Trabajo práctico de Bases de Datos Aplicada (3641, UNLaM) — Sistema de registro y gestión del Mundial de Fútbol, en SQL Server.
Grupo N° 4, comisión 02-5600.

- `sql/`: scripts T-SQL de la Entrega 5, numerados con dos dígitos que indican el orden de ejecución.
- `MundialDB.ssmssln`: solución de SSMS con los scripts en ese orden.
- `doc/`: documentación de las entregas (DER y Entrega 5 en PDF, con la norma de nomenclatura).

## Cómo ejecutarlo

1. Verificar que existan `D:\SQLData` y `D:\SQLLogs` (si son otras, editar las dos rutas de la sección CONFIGURACIÓN de `sql/01_Base_Esquemas.sql`).
2. Abrir `MundialDB.ssmssln` en SSMS y ejecutar los scripts con F5, de arriba hacia abajo, una sola vez.

El script 01 elimina y vuelve a crear `MundialDB`. Para empezar de nuevo basta con ejecutar otra vez desde el 01.
Probado en SQL Server 2025 Express.

## Integrantes

- Avila, Agustín — @AvilaAlexAgustin
- Blanco, Pablo — @bnpablo
- Leopaldi, Agustín — @agustinleopaldi
- Sosa, Jesús — @periodistaunlam2023-cpu
