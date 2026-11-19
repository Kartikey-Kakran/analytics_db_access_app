"""Small syntax-colored SQL editor implemented as a local Streamlit component."""

from pathlib import Path

import streamlit.components.v1 as components


_declare_component = components.declare_component
_sql_editor_component = _declare_component(
    "cp_duckdb_sql_editor",
    path=str(Path(__file__).with_name("sql_editor_frontend")),
)


def sql_editor(value, tables, columns, height=300, key=None):
    """Render the editor and return its current SQL text."""
    return _sql_editor_component(
        value=value,
        tables=tables,
        columns=columns,
        height=height,
        default=value,
        key=key,
    )
