# pagila-rental-api-inter
Proyecto base para trabajar con la base de datos de ejemplo *Pagila* usando *PostgreSQL en Docker*.

Actualmente este repositorio deja listo el entorno de base de datos para desarrollo local, con scripts de esquema y datos iniciales.

## Requisitos

- Docker Desktop
- Docker Compose (incluido en Docker Desktop)

## Estructura del proyecto

text
pagila-rental-api/
├── app/
│   ├── db.py
│   ├── main.py
│   ├── models.py
│   └── requirements.txt
├── docker/
│   ├── pagila-schema.sql
│   └── pagila-data.sql
├── scripts/
│   └── pgbench/
├── sql/
│   └── queries.sql
├── docker-compose.yml
└── README.md


## Levantar la base de datos

Desde la raíz del proyecto:

bash
docker compose up -d


Esto inicia un contenedor PostgreSQL con:

- Usuario: postgres
- Contraseña: postgres
- Base de datos: pagila
- Puerto local: 5434

## Inicialización automática de Pagila

Al iniciar por primera vez, Docker ejecuta automáticamente los scripts montados en docker-entrypoint-initdb.d:

1. docker/pagila-schema.sql → crea la estructura (tablas, relaciones, etc.)
2. docker/pagila-data.sql → carga los datos de ejemplo

> Importante: estos scripts se ejecutan automáticamente solo cuando el volumen de datos está vacío.

## Conexión a PostgreSQL

Puedes conectarte con cualquier cliente SQL usando:

- Host: localhost
- Puerto: 5434
- Usuario: postgres
- Contraseña: postgres
- Base de datos: pagila

Ejemplo con psql:

bash
psql -h localhost -p 5434 -U postgres -d pagila


## Comandos útiles

Detener servicios:

bash
docker compose down


Detener y eliminar también el volumen de datos (reinicio completo):

bash
docker compose down -v


Ver logs de la base de datos:

bash
docker compose logs -f db

## Pagila Rental API - Core Backend 

Una API RESTful robusta construida con *FastAPI* y *PostgreSQL* (mediante SQLAlchemy) para gestionar el ciclo de vida de un sistema de renta de películas tipo Blockbuster. 

Este proyecto se centra en la integridad de los datos, el manejo avanzado de transacciones y la prevención de condiciones de carrera (concurrency) en entornos de alta demanda.

## Tecnologías Utilizadas
* *Framework:* FastAPI (Python)
* *Base de Datos:* PostgreSQL
* *ORM / Query Builder:* SQLAlchemy Core
* *Validación de Datos:* Pydantic

## Características Principales y Endpoints

### 1. Rentas (POST /rentals)
Permite a un cliente rentar una película física.
* *Integridad:* Verifica la existencia del inventory_id y asegura que la película no tenga una renta activa.
* *Bloqueo Pesimista:* Utiliza SELECT ... FOR UPDATE para bloquear la fila del inventario, previniendo que dos usuarios renten la misma copia física en el mismo milisegundo.

### 2. Devoluciones (POST /returns/{rental_id})
Registra la devolución de una película al inventario físico.
* *Idempotencia:* Diseñado para ser seguro ante reintentos. Si se envía la petición de devolución sobre una película ya devuelta, la API responde con éxito sin duplicar efectos ni romper la consistencia.

### 3. Pagos (POST /payments)
Procesa los pagos de los clientes, con o sin asociación directa a un ticket de renta.
* *Validación Cruzada (Antifraude):* Si se proporciona un rental_id, el sistema verifica dinámicamente que el ticket pertenezca exactamente al customer_id que está intentando pagar, bloqueando la transacción (403 Forbidden) en caso de discrepancia.

##  Manejo Avanzado de Base de Datos

Este backend está diseñado para soportar alta concurrencia cumpliendo con principios ACID:

* *Transacciones Explícitas:* Todas las operaciones de escritura están envueltas en bloques de transacciones (BEGIN / COMMIT / ROLLBACK automático) para garantizar la atomicidad.
* *Niveles de Aislamiento Dinámicos:*
  * Uso de READ COMMITTED como nivel base para el motor general.
  * Elevación dinámica a REPEATABLE READ específicamente en el endpoint de devoluciones para asegurar lecturas consistentes durante la transacción.
* *Retry con Exponential Backoff:* Implementación de un sistema de reintentos automáticos que intercepta errores de concurrencia nativos de PostgreSQL (Deadlocks 40P01 y Serialization Failures 40001), escalando el tiempo de espera exponencialmente antes de abortar la petición con un error 500.

#  Sistema de Triggers y Auditoría (PostgreSQL)
Este módulo contiene la lógica de base de datos diseñada para garantizar la integridad del negocio y el cumplimiento (compliance) a través de **Triggers** y **Funciones en PL/pgSQL**. 

Se divide en dos componentes principales integrados en el archivo `sql/triggers.sql`: la regla de negocio preventiva ("El Cadenero") y el sistema de trazabilidad ("El Chismoso").

## 1. Regla de Negocio Preventiva (Límite de Rentas)
Para evitar el acaparamiento de inventario, el sistema bloquea transacciones a nivel de base de datos antes de que ocurran.

* **Tipo:** `BEFORE INSERT` en la tabla `rental`.
* **Función:** `check_active_rentals()`
* **Comportamiento:** 1. Cuenta cuántas rentas activas (`return_date IS NULL`) tiene el `customer_id` que intenta hacer la nueva renta.
  2. Si el cliente ya tiene **3 o más rentas activas**, el trigger lanza una excepción (`RAISE EXCEPTION`).
  3. La transacción se aborta automáticamente, devolviendo un error a la aplicación con el mensaje: *"ALERTA DE NEGOCIO: Límite superado"*.

## 2. Sistema de Auditoría (Trazabilidad JSONB)
Para cumplir con los requisitos de auditoría de la empresa, todo cambio en la tabla de rentas queda registrado históricamente.

* **Tipo:** `AFTER INSERT OR UPDATE OR DELETE` en la tabla `rental`.
* **Función:** `audit_changes()`
* **Comportamiento:**
  1. Detecta qué tipo de operación se realizó (`TG_OP`).
  2. Inserta un nuevo registro en la tabla `audit_log`.
  3. Captura el usuario de la sesión (`session_user`) y la marca de tiempo exacta.
  4. Guarda el estado de la fila antes (`OLD`) y después (`NEW`) de la modificación utilizando el formato `JSONB` (`row_to_json`), lo que permite consultas flexibles sobre el historial.

##  Instalación y Uso
Todo el código está consolidado en un solo script para facilitar su despliegue.

###  Credenciales de Acceso (Entorno de Desarrollo)
Si estás evaluando este proyecto, utiliza las siguientes credenciales para conectarte al contenedor Docker:
* **Usuario:** `postgres`
* **Contraseña:** `postgres`
* **Base de Datos:** `pagila`

### Pasos de Ejecución:
1. Abre tu cliente de PostgreSQL (pgAdmin, DBeaver o psql) y conéctate usando las credenciales de arriba.
2. Ejecuta el contenido completo del archivo `sql/triggers.sql` en el Query Tool.
   * *Nota: El script es idempotente (incluye comandos `DROP TRIGGER IF EXISTS`), por lo que puedes ejecutarlo varias veces sin causar errores.*

## Cómo probarlo
### Probar la Regla de Negocio:
Intenta insertar 4 rentas para el mismo cliente sin fecha de devolución. Las primeras 3 pasarán, la 4ta marcará error:
```sql
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id) VALUES (NOW(), 1, 1, 1);
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id) VALUES (NOW(), 2, 1, 1);
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id) VALUES (NOW(), 3, 1, 1);
-- La siguiente línea detonará la alerta del trigger:
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id) VALUES (NOW(), 4, 1, 1);

# Indices 

La presente sección justifica la estrategia de indexación implementada. Las decisiones técnicas tomadas aquí responden a la urgencia de estabilizar la base de datos y detener la severa degradación de rendimiento observada durante las pruebas de carga.

## Indice parcial
El trigger de validación colapsaba el rendimiento general al verse obligado a escanear el historial completo de rentas de cada cliente en cada petición. Era insostenible mantener el sistema sin esta optimización, por lo que la lectura se restringió explícitamente a las transacciones activas:

    CREATE INDEX IF NOT EXISTS idx_rental_customer_active 
    ON rental(customer_id) 
    WHERE return_date IS NULL;

## Indices de llaves foráneas
PostgreSQL no indexa llaves foráneas por defecto. Dado que depende de sqlalchemy, la resolución de relaciones mediante JOINs provocaba escaneos secuenciales masivos. La ausencia de estos índices estrangulaba el flujo de datos y generaba cuellos de botella inaceptables en el servidor, haciendo estrictamente obligatoria su creación:

    CREATE INDEX IF NOT EXISTS idx_rental_inventory_id ON rental(inventory_id);
    CREATE INDEX IF NOT EXISTS idx_rental_staff_id ON rental(staff_id);
    CREATE INDEX IF NOT EXISTS idx_rental_date ON rental(rental_date);
    CREATE INDEX IF NOT EXISTS idx_inventory_film_id ON inventory(film_id);

## Instrucciones de despliegue
Para aplicar estos cambios en el entorno y restaurar la operatividad del sistema, ejecute las sentencias en pgAdmin o corra el script completo a través de la consola mediante psql. Las sentencias están protegidas para ignorar conflictos en caso de que los índices ya existan.

    psql -U postgres -d pagila -f sql/indexes.sql

