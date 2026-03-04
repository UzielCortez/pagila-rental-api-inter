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