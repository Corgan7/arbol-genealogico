-- ============================================================================
-- ARCHIVO FAMILIAR BARRIOS – CARRASCO
-- Esquema para el proyecto arbol-genealogico (bcwgezdbqkvuellkzkvs)
--
-- Pégalo entero en: Supabase → SQL Editor → New query → Run
-- Es idempotente: puedes ejecutarlo varias veces sin romper nada.
--
-- PRINCIPIO DE SEGURIDAD
--   La familia puede ESCRIBIR pero no LEER.
--   Nadie ve las aportaciones de los demás.
--   Del árbol solo es público lo que tú marques como publicable,
--   y nunca las personas vivas.
-- ============================================================================

-- ============================================================================
-- 1 · FICHA — lo que la familia aporta desde el formulario
--     Cada fila es una APORTACIÓN, no un hecho verificado.
-- ============================================================================

create table if not exists public.ficha (
  id                    bigint generated always as identity primary key,
  creado_en             timestamptz not null default now(),

  informante_nombre     text not null,
  informante_parentesco text,
  informante_contacto   text,

  persona_nombre        text not null,
  persona_apodo         text,
  persona_vive          text,

  nac_fecha             text,
  nac_lugar             text,
  nac_certeza           text,

  def_fecha             text,
  def_lugar             text,
  def_entierro          text,
  def_certeza           text,

  padre                 text,
  madre                 text,
  padres_notas          text,
  padres_certeza        text,

  hermanos              text,
  conyuge               text,
  mat_fecha             text,
  mat_lugar             text,
  mat_suegros           text,
  mat_otros             text,
  mat_certeza           text,
  hijos                 text,

  oficios               text,
  viviendas             text,
  propiedades           text,
  episodios             text,

  documentos_tipos      text[],
  documentos_notas      text,
  recuerdos             text,
  quien_mas             text,
  extra                 text,

  estado                text not null default 'nueva'
                        check (estado in ('nueva','revisada','incorporada','descartada')),
  notas_internas        text,
  user_agent            text
);

comment on table public.ficha is
  'Aportaciones de familiares. Se conservan tal cual llegaron, sin corregir.';

create index if not exists ix_ficha_persona on public.ficha (persona_nombre);
create index if not exists ix_ficha_estado  on public.ficha (estado, creado_en desc);

-- ============================================================================
-- 2 · PERSONA — el árbol
-- ============================================================================

create table if not exists public.persona (
  id            text primary key,
  nombre        text not null,
  apodo         text,
  sexo          text check (sexo in ('M','F') or sexo is null),

  nac_fecha     text,          -- EDTF: 1912-10-04, 1948, ~1888, 1942/1946
  nac_lugar     text,
  def_fecha     text,
  def_lugar     text,

  oficio        text,
  generacion    int,           -- 1 = generación del promotor
  rama          text check (rama in ('yo','pat','mat','pol') or rama is null),
  linea_directa boolean not null default false,
  viva          boolean not null default false,
  casilla       boolean not null default false,  -- hueco sin identificar
  apellido_deducido text,

  visibilidad   text not null default 'familiar'
                check (visibilidad in ('publico','familiar','privado')),
  estado        text not null default 'activa'
                check (estado in ('activa','candidata','fusionada')),
  fusionada_en  text references public.persona(id),
  notas         text,
  actualizado   timestamptz not null default now()
);

comment on table public.persona is 'Personas del árbol. Incluye casillas vacías sin identificar.';

create table if not exists public.parentesco (
  id        bigint generated always as identity primary key,
  origen    text not null references public.persona(id) on delete cascade,
  tipo      text not null check (tipo in ('padre_de','madre_de','conyuge_de')),
  destino   text not null references public.persona(id) on delete cascade,
  desde     text,
  hasta     text,
  unique (origen, tipo, destino)
);

create index if not exists ix_parentesco_origen  on public.parentesco (origen, tipo);
create index if not exists ix_parentesco_destino on public.parentesco (destino, tipo);

-- ============================================================================
-- 3 · FUENTE y ASERCIÓN — el modelo de certeza
--     No se guardan hechos: se guardan afirmaciones con su respaldo.
-- ============================================================================

create table if not exists public.fuente (
  id          text primary key,
  clave       text not null,
  tipo_base   text not null,   -- original / derivada / publicada / testigo_presencial /
                               -- testimonio_indirecto / tradicion / inferencia_propia /
                               -- inferencia_ia / ninguna
  cita        text,
  localizacion text,
  consultada  boolean not null default false,
  ficha_id    bigint references public.ficha(id),
  notas       text
);

comment on column public.fuente.consultada is
  'false = nadie ha visto el documento con sus propios ojos todavía.';

create table if not exists public.asercion (
  id            bigint generated always as identity primary key,
  sujeto        text not null references public.persona(id) on delete cascade,
  predicado     text not null,
  valor         text,
  valor_persona text references public.persona(id),

  fuente_id     text references public.fuente(id),
  base          text not null check (base in
                 ('original','derivada','publicada','testigo_presencial',
                  'testimonio_indirecto','tradicion','inferencia_propia',
                  'inferencia_ia','ninguna')),
  confianza     text not null check (confianza in
                 ('cierto','muy_probable','probable','posible','dudoso','descartado')),
  tipo          text not null default 'hecho' check (tipo in ('hecho','interpretacion')),
  visibilidad   text not null default 'familiar'
                check (visibilidad in ('publico','familiar','privado')),

  aportado_por  text,
  registrado_el timestamptz not null default now(),
  notas         text
);

create index if not exists ix_asercion_sujeto on public.asercion (sujeto, predicado);

-- cardinalidad: sin esto, tener nueve hijos parece una contradicción
create table if not exists public.predicado (
  nombre       text primary key,
  cardinalidad text not null check (cardinalidad in ('unico','multiple')),
  descripcion  text
);

insert into public.predicado (nombre, cardinalidad) values
  ('nacimiento','unico'), ('defuncion','unico'), ('causa_muerte','unico'),
  ('padre_de','multiple'), ('madre_de','multiple'), ('hermano_de','multiple'),
  ('conyuge','multiple'), ('profesion','multiple'), ('domicilio','multiple'),
  ('propiedad','multiple'), ('negocio','multiple'), ('traslado','multiple')
on conflict (nombre) do nothing;

-- contradicciones reales: mismo sujeto, mismo predicado único, valores distintos
create or replace view public.conflicto as
  select a.sujeto, a.predicado,
         count(distinct coalesce(a.valor, a.valor_persona)) as versiones
    from public.asercion a
    join public.predicado p on p.nombre = a.predicado
   where a.tipo = 'hecho' and p.cardinalidad = 'unico'
   group by a.sujeto, a.predicado
  having count(distinct coalesce(a.valor, a.valor_persona)) > 1;

-- ============================================================================
-- 4 · ARCHIVO — fotos, documentos y audios
-- ============================================================================

create table if not exists public.archivo (
  id           bigint generated always as identity primary key,
  creado_en    timestamptz not null default now(),
  tipo         text not null check (tipo in ('foto','documento','audio','video','otro')),
  titulo       text,
  descripcion  text,
  ruta         text,          -- ruta en Supabase Storage
  persona_id   text references public.persona(id),
  fuente_id    text references public.fuente(id),
  ficha_id     bigint references public.ficha(id),
  aportado_por text,
  fecha_original text,
  lugar        text,
  visibilidad  text not null default 'familiar'
               check (visibilidad in ('publico','familiar','privado'))
);

-- ============================================================================
-- 5 · SEGURIDAD
-- ============================================================================

alter table public.ficha      enable row level security;
alter table public.persona    enable row level security;
alter table public.parentesco enable row level security;
alter table public.fuente     enable row level security;
alter table public.asercion   enable row level security;
alter table public.predicado  enable row level security;
alter table public.archivo    enable row level security;

-- la familia solo puede insertar fichas, y nada más
drop policy if exists ficha_insert_anon on public.ficha;
create policy ficha_insert_anon
  on public.ficha for insert to anon, authenticated
  with check (
    length(coalesce(informante_nombre,'')) between 2 and 120
    and length(coalesce(persona_nombre,'')) between 2 and 200
    and estado = 'nueva'
  );

-- sin más políticas: todo lo demás queda denegado para anon.
-- tú lees y editas desde el panel de Supabase, que usa la clave de servicio.

revoke all on public.ficha      from anon, authenticated;
revoke all on public.persona    from anon, authenticated;
revoke all on public.parentesco from anon, authenticated;
revoke all on public.fuente     from anon, authenticated;
revoke all on public.asercion   from anon, authenticated;
revoke all on public.predicado  from anon, authenticated;
revoke all on public.archivo    from anon, authenticated;

grant insert on public.ficha to anon, authenticated;

-- ============================================================================
-- 6 · VISTA PÚBLICA DEL ÁRBOL
--     Lo único que la web puede leer. Excluye personas vivas SIEMPRE,
--     y solo muestra lo que esté marcado como publicable.
-- ============================================================================

create or replace view public.arbol_publico
with (security_invoker = true) as
  select p.id, p.nombre, p.apodo, p.sexo,
         p.nac_fecha, p.nac_lugar, p.def_fecha, p.def_lugar,
         p.oficio, p.generacion, p.rama, p.linea_directa,
         p.casilla, p.apellido_deducido
    from public.persona p
   where p.viva = false
     and p.visibilidad = 'publico'
     and p.estado = 'activa';

create or replace view public.parentesco_publico
with (security_invoker = true) as
  select r.origen, r.tipo, r.destino
    from public.parentesco r
    join public.persona a on a.id = r.origen
    join public.persona b on b.id = r.destino
   where a.viva = false and a.visibilidad = 'publico'
     and b.viva = false and b.visibilidad = 'publico';

-- para que las vistas funcionen con security_invoker hace falta permiso de lectura
-- sobre las filas que dejan pasar. Se concede solo lo justo:
drop policy if exists persona_select_publica on public.persona;
create policy persona_select_publica
  on public.persona for select to anon, authenticated
  using (viva = false and visibilidad = 'publico' and estado = 'activa');

drop policy if exists parentesco_select_publico on public.parentesco;
create policy parentesco_select_publico
  on public.parentesco for select to anon, authenticated
  using (
    exists (select 1 from public.persona x
             where x.id = origen and x.viva = false and x.visibilidad = 'publico')
    and exists (select 1 from public.persona y
                 where y.id = destino and y.viva = false and y.visibilidad = 'publico')
  );

grant select on public.persona, public.parentesco to anon, authenticated;
grant select on public.arbol_publico, public.parentesco_publico to anon, authenticated;

-- ============================================================================
-- 7 · COMPROBACIÓN
-- ============================================================================

select table_name,
       (select count(*) from pg_policies
         where schemaname = 'public' and tablename = t.table_name) as politicas
  from information_schema.tables t
 where table_schema = 'public'
   and table_name in ('ficha','persona','parentesco','fuente','asercion','predicado','archivo')
 order by table_name;
