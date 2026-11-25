# bda-mundial-2026

Trabajo práctico de Bases de Datos Aplicada (3641, UNLaM) — Sistema de registro y gestión del Mundial de Fútbol, en SQL Server.
Grupo N° 4, comisión 02-5600.

- `sql/`: scripts T-SQL de las Entregas 5 a 9, numerados con dos dígitos que indican el orden de ejecución.
- `MundialDB.ssmssln`: solución de SSMS con los scripts en ese orden.
- `app/`: aplicación de escritorio en Python (Entrega 9).
- `doc/`: documentación de las entregas (DER, instalación y Entregas 5 a 9 en PDF).

## Cómo ejecutarlo

1. Verificar que existan `D:\SQLData` y `D:\SQLLogs` (si son otras, editar las dos rutas de la sección CONFIGURACIÓN de `sql/01_Base_Esquemas.sql`).
2. Abrir `MundialDB.ssmssln` en SSMS y ejecutar los scripts con F5, de arriba hacia abajo, una sola vez.

3. Importaciones (Entrega 6): crear `C:\Importar` y descargar los dos archivos desde CMD:

```
mkdir C:\Importar
curl -f -L -o C:\Importar\referees.csv https://raw.githubusercontent.com/jfjelstul/worldcup/master/data-csv/referees.csv
curl -f -L -o C:\Importar\dossier.html https://dossiermundial.netlify.app/
```

   La cuenta del servicio de SQL Server necesita permiso de lectura y escritura sobre esa carpeta (detalle en `doc/Entrega6_Procesos_de_Importacion.pdf`).
   El script 07 activa `Ole Automation Procedures` y requiere un usuario sysadmin.

El script 01 elimina y vuelve a crear `MundialDB`. Para empezar de nuevo basta con ejecutar otra vez desde el 01.
Los scripts `99_Datos_Aceptacion.sql`, `99_Demo_Reportes.sql`, `99_Seguridad_1` a `99_Seguridad_7` y `99_Visualizacion_1` a `99_Visualizacion_6` van al final y en ese orden. Los de seguridad (Entrega 8) cifran los datos personales y crean los roles; sus tests muestran los permisos de cada usuario. Los de visualización (Entrega 9) agregan la geolocalización de las sedes, las consultas faltantes del alcance, las vistas y el usuario de solo lectura para la plataforma de BI, con sus tests.
Requiere SQL Server 2022 o posterior; probado en SQL Server 2025 Express.

## Aplicación (Entrega 9)

Requiere Python 3.9 o posterior y ODBC Driver 18 para SQL Server. Se conecta a `localhost\SQLEXPRESS`, base `MundialDB`, con la cuenta de Windows (se cambia con las variables de entorno `MUNDIAL_SERVIDOR` y `MUNDIAL_BASE`):

```
pip install pyodbc
python app\app_mundial.py
```

## Integrantes

- Avila, Agustín — @AvilaAlexAgustin
- Blanco, Pablo — @bnpablo
- Leopaldi, Agustín — @agustinleopaldi
- Sosa, Jesús — @periodistaunlam2023-cpu
