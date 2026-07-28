# Archivo familiar Barrios – Carrasco

Reconstrucción documentada de la historia de la familia Barrios, Vizuete, Balsera,
Carrasco y Muñoz, entre el Valle del Guadiato (Córdoba), los Montes de Ciudad Real
y Berrocal de Salvatierra (Salamanca).

## Qué hay aquí

| Archivo | Qué es |
|---|---|
| `index.html` | Formulario para que la familia aporte fichas. Escribe directo en Supabase. |
| `sql/esquema.sql` | Esquema completo de la base de datos, con sus políticas de seguridad. |

## El principio que sostiene todo

**No se guardan hechos: se guardan afirmaciones.**

Cada dato lleva pegados cuatro campos que normalmente se pierden:

- **base** — qué lo sustenta: documento original, obra publicada, testigo presencial,
  memoria familiar, tradición, deducción propia
- **confianza** — cuán probable es que sea verdad: cierto, muy probable, probable,
  posible, dudoso, descartado
- **tipo** — si es un hecho o una interpretación
- **visibilidad** — público, familiar o privado

Base y confianza son ejes distintos. Un matrimonio puede ser **cierto** sin que exista
un papel a mano; un pasaje **publicado** en un libro puede ser solo **posible** mientras
nadie haya abierto ese libro. Mezclarlos es lo que convierte una investigación en una
leyenda familiar.

Por eso el modelo conserva las contradicciones en vez de resolverlas. Dos versiones
distintas de un mismo hecho valen más que una versión limpia: la contradicción señala
dónde hay que mirar.

## Seguridad

La familia **puede escribir pero no leer**. Nadie ve las aportaciones de los demás,
ni siquiera las propias.

Del árbol solo son legibles las personas marcadas expresamente como publicables, y
**nunca las personas vivas**, que quedan excluidas por la propia política de la base
de datos y no por buena voluntad de nadie.

## Poner en marcha

1. Crear un proyecto en Supabase.
2. Ejecutar `sql/esquema.sql` en el SQL Editor.
3. En `index.html`, ajustar `SUPABASE_URL` y `SUPABASE_KEY` con los del proyecto.
   La clave publicable es pública por diseño: solo permite insertar fichas.
4. Publicar con GitHub Pages y repartir el enlace.

## Conservación

La historia familiar no debe quedar atrapada en ninguna plataforma. Exportaciones
previstas: GEDCOM 7 para interoperar, paquete completo en JSON y SQLite para
preservar, y volcado a sitio estático — una carpeta de HTML que funcione en cualquier
ordenador dentro de treinta años, sin servidor y sin empresa detrás.
