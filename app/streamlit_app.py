import re
from html import escape

import streamlit as st

from app.db import TABLE_FILES, TABLE_GROUPS, connect
from app.sql_editor import sql_editor


st.set_page_config(
    page_title="CP Data SQL Studio",
    page_icon="◈",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    """
    <style>
      :root { --ink:#e7e7e8; --muted:#a3a4a8; --accent:#ff9800; --line:#383a3e; --surface:#252629; }
      .stApp { background:#191a1d; color:var(--ink); }
      [data-testid="stHeader"] { background:rgba(25,26,29,.96); }
      [data-testid="stSidebar"] { background:#222326; border-right:1px solid #35363a; }
      [data-testid="stSidebar"] > div { padding-top:1.25rem; }
      [data-testid="stSidebar"] h2, [data-testid="stSidebar"] label,
      [data-testid="stSidebar"] p, [data-testid="stSidebar"] span { color:var(--ink); }
      [data-testid="stSidebar"] [data-testid="stExpander"] { background:#292a2e; border:1px solid var(--line); border-radius:8px; }
      .hero { padding:.5rem 0 1.1rem; border-bottom:1px solid var(--line); margin-bottom:1.25rem; }
      .hero-kicker { color:var(--accent); font-size:.72rem; font-weight:700; letter-spacing:.12em;
        text-transform:uppercase; margin-bottom:.35rem; }
      .hero h1 { color:var(--ink); font-size:2rem; font-weight:700; margin:0; }
      .hero p { color:var(--muted); margin:.35rem 0 0; }
      div.stButton > button[kind="primary"] { background:var(--accent); border-color:var(--accent); color:#17181a; font-weight:700; }
      div.stButton > button[kind="primary"]:hover { background:#ffad33; border-color:#ffad33; }
      [data-testid="stMetric"] { background:#222326; border:1px solid var(--line); padding:.8rem 1rem; border-radius:8px; }
      [data-testid="stMetricLabel"] { color:var(--muted); }
      [data-testid="stMetricValue"] { color:var(--ink); }
      [data-testid="stDataFrame"] { border:1px solid var(--line); border-radius:8px; background:#202124; }
      [data-testid="stTextArea"] textarea { background:#202124; color:#f0f0f0; border-color:#44464b; }
      [data-testid="stTextInput"] input, [data-testid="stSelectbox"] [data-baseweb="select"] > div { background:#2b2c30; color:var(--ink); }
      code { color:#ffad33 !important; background:#332817 !important; }
    </style>
    """,
    unsafe_allow_html=True,
)


@st.cache_data(show_spinner="Reading table columns…")
def get_catalog():
    con = connect()
    try:
        catalog = {}
        for table_name in TABLE_FILES:
            safe_name = table_name.replace('"', '""')
            rows = con.execute(f'DESCRIBE SELECT * FROM "{safe_name}"').fetchall()
            catalog[table_name] = [(row[0], row[1]) for row in rows]
        return catalog
    finally:
        con.close()


def get_suggestions(query_text, schema):
    """Suggest table names and schema columns from the active SQL context."""
    # Ignore a trailing semicolon while interpreting an unfinished final clause.
    active_sql = query_text.rstrip()
    if active_sql.endswith(";"):
        active_sql = active_sql[:-1].rstrip()
    if not active_sql:
        return None, []

    table_match = re.search(
        r"\b(?:FROM|JOIN)(?:\s+([A-Za-z_][A-Za-z0-9_$]*))?\s*$",
        active_sql,
        re.IGNORECASE,
    )
    if table_match:
        prefix = table_match.group(1) or ""
        candidates = list(TABLE_FILES)
        kind = "table"
    else:
        # Build the referenced table and alias map for more relevant columns.
        table_aliases = {}
        reserved = {"WHERE", "JOIN", "ON", "LEFT", "RIGHT", "INNER", "FULL", "CROSS", "GROUP", "ORDER", "LIMIT", "UNION"}
        relation_pattern = re.compile(
            r"\b(?:FROM|JOIN)\s+([A-Za-z_][A-Za-z0-9_$]*)(?:\s+(?:AS\s+)?([A-Za-z_][A-Za-z0-9_$]*))?",
            re.IGNORECASE,
        )
        for relation in relation_pattern.finditer(active_sql):
            table_name, alias = relation.group(1), relation.group(2)
            if table_name in schema:
                table_aliases[table_name.casefold()] = table_name
                if alias and alias.upper() not in reserved:
                    table_aliases[alias.casefold()] = table_name

        qualified_match = re.search(
            r"([A-Za-z_][A-Za-z0-9_$]*)\.([A-Za-z_][A-Za-z0-9_$]*)?$",
            active_sql,
        )
        token_match = re.search(r"([A-Za-z_][A-Za-z0-9_$]*)$", active_sql)
        clause_match = re.search(
            r"(?:\bSELECT|\bWHERE|\bAND|\bOR|\bON|\bBY|,)\s*$",
            active_sql,
            re.IGNORECASE,
        )

        if qualified_match:
            qualifier = qualified_match.group(1).casefold()
            prefix = qualified_match.group(2) or ""
            source_table = table_aliases.get(qualifier)
            source_tables = [source_table] if source_table else list(schema)
            candidates = sorted({column for table in source_tables for column, _ in schema[table]})
            kind = "column"
        elif token_match:
            prefix = token_match.group(1)
            source_tables = list(dict.fromkeys(table_aliases.values())) or list(schema)
            candidates = sorted({column for table in source_tables for column, _ in schema[table]})
            kind = "column"
        elif clause_match:
            prefix = ""
            source_tables = list(dict.fromkeys(table_aliases.values())) or list(schema)
            candidates = sorted({column for table in source_tables for column, _ in schema[table]})
            kind = "column"
        else:
            return None, []

    matches = [name for name in candidates if name.casefold().startswith(prefix.casefold())]
    return kind, matches[:20]


def split_sql_statements(sql_text):
    """Split SQL on semicolons outside quoted strings and SQL comments."""
    statements = []
    start = 0
    i = 0
    quote = None
    line_comment = False
    block_comment = False

    while i < len(sql_text):
        char = sql_text[i]
        next_char = sql_text[i + 1] if i + 1 < len(sql_text) else ""

        if line_comment:
            if char == "\n":
                line_comment = False
        elif block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
                i += 1
        elif quote:
            if char == quote:
                if next_char == quote:  # SQL escapes quote characters by doubling them.
                    i += 1
                else:
                    quote = None
        elif char == "-" and next_char == "-":
            line_comment = True
            i += 1
        elif char == "/" and next_char == "*":
            block_comment = True
            i += 1
        elif char in ("'", '"', "`"):
            quote = char
        elif char == ";":
            statement = sql_text[start:i].strip()
            if statement:
                statements.append(statement)
            start = i + 1
        i += 1

    final_statement = sql_text[start:].strip()
    if final_statement:
        statements.append(final_statement)
    return statements


def add_query():
    query_id = st.session_state.query_counter + 1
    st.session_state.query_counter = query_id
    st.session_state.query_ids.append(query_id)
    st.session_state[f"query_sql_{query_id}"] = "SELECT *\nFROM cp_main\nLIMIT 100;"


def run_query(query_id, statement):
    con = None
    try:
        con = connect()
        result = con.execute(statement)
        if result.description:
            st.session_state[f"result_filters_{query_id}"] = []
            st.session_state[f"filter_logic_{query_id}"] = "AND"
            st.session_state[f"filter_version_{query_id}"] = (
                st.session_state.get(f"filter_version_{query_id}", 0) + 1
            )
            st.session_state[f"query_result_{query_id}"] = {
                "data": result.df(),
                "statement": statement,
                "error": None,
            }
        else:
            st.session_state[f"query_result_{query_id}"] = {
                "data": None,
                "statement": statement,
                "message": "Statement completed successfully.",
                "error": None,
            }
    except Exception as error:
        st.session_state[f"query_result_{query_id}"] = {
            "data": None,
            "statement": statement,
            "error": str(error),
        }
    finally:
        if con is not None:
            con.close()


def clear_result_filters(query_id):
    st.session_state[f"result_filters_{query_id}"] = []
    st.session_state[f"filter_logic_{query_id}"] = "AND"


def remove_filter_rule(query_id, rule_index):
    rules = list(st.session_state.get(f"result_filters_{query_id}", []))
    if 0 <= rule_index < len(rules):
        rules.pop(rule_index)
    st.session_state[f"result_filters_{query_id}"] = rules


def apply_result_filters(result, rules, logic):
    """Apply selected output filters and combine rules with AND or OR."""
    masks = []
    for rule in rules:
        series = result[rule["column"]]
        operator = rule["operator"]
        values = rule["values"]

        if operator == "IN":
            mask = series.notna() & series.isin(values)
        elif operator == "NOT IN":
            mask = series.notna() & ~series.isin(values)
        elif operator == "=":
            mask = series.notna() & series.eq(values[0])
        elif operator == "!=":
            mask = series.notna() & series.ne(values[0])
        elif operator == "contains":
            mask = series.astype("string").str.contains(
                re.escape(str(values[0])), case=False, na=False
            )
        elif operator == "not contains":
            mask = series.astype("string").str.contains(
                re.escape(str(values[0])), case=False, na=False
            )
            mask = ~mask
        elif operator == "is null":
            mask = series.isna()
        else:  # is not null
            mask = series.notna()
        masks.append(mask)

    if not masks:
        return result

    combined = masks[0].copy()
    for mask in masks[1:]:
        combined = combined & mask if logic == "AND" else combined | mask
    return result[combined]


st.sidebar.markdown("## ◈ Data catalog")
st.sidebar.caption("Browse tables and find column names")
search = st.sidebar.text_input("Search columns", placeholder="e.g. family_id, date, status")
catalog = get_catalog()
selected_table = st.sidebar.selectbox("Table", list(catalog.keys()))
needle = search.strip().casefold()

for group_name, group_tables in TABLE_GROUPS.items():
    with st.sidebar.expander(group_name, expanded=(group_name == "REPLICA survey data")):
        for table_name in group_tables:
            columns = catalog[table_name]
            matching = [
                (column, data_type)
                for column, data_type in columns
                if not needle or needle in column.casefold() or needle in table_name.casefold()
            ]
            if not matching:
                continue
            label = f"{table_name} · {len(matching)} of {len(columns)} columns"
            with st.expander(label, expanded=(table_name == selected_table or bool(needle))):
                for column, data_type in matching:
                    st.markdown(
                        f"`{column}` <span style='color:#a3a4a8'>· {data_type}</span>",
                        unsafe_allow_html=True,
                    )

st.markdown(
    """
    <div class="hero">
      <div class="hero-kicker">Local analytics workspace</div>
      <h1>CP Data SQL Studio</h1>
      <p>Write SQL against your CSV and Parquet files using familiar table names.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

if "query_ids" not in st.session_state:
    st.session_state.query_ids = [1]
    st.session_state.query_counter = 1
    st.session_state.query_sql_1 = """SELECT COUNT(*) AS row_count
FROM family_details;"""

header_left, header_right = st.columns([4, 1])
with header_left:
    st.markdown("### Query workspace")
with header_right:
    st.button("＋ New query", on_click=add_query, use_container_width=True)

query_tabs = st.tabs([f"Query {query_id}" for query_id in st.session_state.query_ids])
for query_id, query_tab in zip(st.session_state.query_ids, query_tabs):
    with query_tab:
        sql_key = f"query_sql_{query_id}"
        st.caption("SQL keywords · purple    Tables · orange    Columns · blue")
        sql = sql_editor(
            value=st.session_state.get(sql_key, ""),
            tables=list(TABLE_FILES),
            columns={
                table_name: [column for column, _ in table_columns]
                for table_name, table_columns in catalog.items()
            },
            height=300,
            key=sql_key,
        )
        if sql is None:
            sql = st.session_state.get(sql_key, "")
        statements = split_sql_statements(sql)

        if len(statements) > 1:
            st.caption(f"This editor has {len(statements)} statements. Choose which one to run:")
            chosen_statement = st.selectbox(
                "Statement to run",
                statements,
                format_func=lambda statement: (
                    f"Statement {statements.index(statement) + 1} · "
                    f"{statement.splitlines()[0][:72]}"
                ),
                key=f"statement_select_{query_id}",
                label_visibility="collapsed",
            )
        elif statements:
            chosen_statement = statements[0]
        else:
            chosen_statement = ""

        suggestion_kind, suggestions = get_suggestions(sql, catalog)
        if suggestion_kind:
            st.caption(f"Suggestions · {suggestion_kind}s")
            if suggestions:
                suggestion_chips = " ".join(
                    f"<code>{escape(suggestion)}</code>" for suggestion in suggestions
                )
                st.markdown(suggestion_chips, unsafe_allow_html=True)
            else:
                st.caption("No matching names. Keep typing to refine the search.")

        if st.button(
            f"▶  Run Query {query_id}",
            type="primary",
            key=f"run_query_{query_id}",
            disabled=not chosen_statement,
        ):
            run_query(query_id, chosen_statement)

        query_output = st.session_state.get(f"query_result_{query_id}")
        if query_output:
            st.markdown("### Results")
            if query_output["error"]:
                st.error(f"Query failed: {query_output['error']}")
            elif query_output.get("data") is None:
                st.success(query_output.get("message", "Statement completed."))
            else:
                result = query_output["data"]
                st.caption(f"Output from: `{query_output['statement'][:180]}`")
                filter_version = st.session_state.get(f"filter_version_{query_id}", 0)
                with st.expander("Filter results by column", expanded=False):
                    st.caption("Choose a result column, then select one or more of its values.")
                    filter_controls = st.columns([1.5, 1, 2.5])
                    with filter_controls[0]:
                        filter_column = st.selectbox(
                            "Column",
                            options=list(result.columns),
                            key=f"filter_column_{query_id}_{filter_version}",
                        )
                    with filter_controls[1]:
                        filter_operator = st.selectbox(
                            "Condition",
                            options=["IN", "NOT IN", "=", "!=", "contains", "not contains", "is null", "is not null"],
                            key=f"filter_operator_{query_id}_{filter_version}",
                        )

                    available_values = result[filter_column].dropna().drop_duplicates().tolist()
                    max_filter_values = 2000
                    values_limited = len(available_values) > max_filter_values
                    if values_limited:
                        available_values = available_values[:max_filter_values]

                    new_filter_values = []
                    if filter_operator in ("IN", "NOT IN"):
                        new_filter_values = st.multiselect(
                            "Values",
                            options=available_values,
                            key=f"filter_values_{query_id}_{filter_version}_{filter_column}",
                            placeholder="Search and select one or more values",
                        )
                    elif filter_operator in ("=", "!="):
                        chosen_value = st.selectbox(
                            "Value",
                            options=available_values,
                            index=None,
                            key=f"filter_value_{query_id}_{filter_version}_{filter_column}",
                            placeholder="Choose a value",
                        )
                        if chosen_value is not None:
                            new_filter_values = [chosen_value]
                    elif filter_operator in ("contains", "not contains"):
                        contains_value = st.text_input(
                            "Value contains",
                            key=f"filter_contains_{query_id}_{filter_version}_{filter_column}",
                            placeholder="Type text to match",
                        )
                        if contains_value:
                            new_filter_values = [contains_value]

                    if values_limited:
                        st.caption(f"Showing the first {max_filter_values:,} distinct values. Type in the selector to search them.")

                    if st.button(
                        "＋ Add filter",
                        key=f"add_filter_{query_id}",
                        disabled=(filter_operator in ("IN", "NOT IN", "=", "!=", "contains", "not contains") and not new_filter_values),
                    ):
                        rules_key = f"result_filters_{query_id}"
                        rules = list(st.session_state.get(rules_key, []))
                        rules.append({
                            "column": filter_column,
                            "operator": filter_operator,
                            "values": new_filter_values,
                        })
                        st.session_state[rules_key] = rules

                    rules_key = f"result_filters_{query_id}"
                    rules = st.session_state.get(rules_key, [])
                    if len(rules) > 1:
                        st.radio(
                            "Combine filters",
                            options=["AND", "OR"],
                            horizontal=True,
                            key=f"filter_logic_{query_id}",
                            help="AND requires every rule to match. OR requires at least one rule to match.",
                        )
                    else:
                        st.session_state.setdefault(f"filter_logic_{query_id}", "AND")

                    for rule_index, rule in enumerate(rules):
                        rule_values = ", ".join(str(value) for value in rule["values"])
                        rule_label = f"{rule['column']} {rule['operator']} {rule_values}".strip()
                        rule_row = st.columns([5, 1])
                        rule_row[0].code(rule_label)
                        rule_row[1].button(
                            "Remove",
                            key=f"remove_filter_{query_id}_{rule_index}",
                            on_click=remove_filter_rule,
                            args=(query_id, rule_index),
                        )

                    st.button(
                        "Clear filters",
                        key=f"clear_filters_{query_id}",
                        on_click=clear_result_filters,
                        args=(query_id,),
                    )

                active_rules = st.session_state.get(f"result_filters_{query_id}", [])
                filter_logic = st.session_state.get(f"filter_logic_{query_id}", "AND")
                filtered_result = apply_result_filters(result, active_rules, filter_logic)

                metric1, metric2 = st.columns(2)
                metric1.metric("Rows shown", f"{len(filtered_result):,} / {len(result):,}")
                metric2.metric("Columns returned", f"{len(filtered_result.columns):,}")
                st.dataframe(filtered_result, use_container_width=True, height=480)
                st.download_button(
                    "Download filtered results as CSV",
                    data=filtered_result.to_csv(index=False).encode("utf-8"),
                    file_name=f"query_{query_id}_results.csv",
                    mime="text/csv",
                    key=f"download_query_{query_id}",
                )
