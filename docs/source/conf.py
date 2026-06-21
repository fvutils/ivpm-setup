# Configuration file for the Sphinx documentation builder.
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------

project = 'ivpm-setup'
copyright = '2026, Matthew Ballance'
author = 'Matthew Ballance'

# -- General configuration ---------------------------------------------------

# rst-first, but allow Markdown (e.g. for reused snippets) via MyST.
extensions = [
    'myst_parser',
]

templates_path = ['_templates']
exclude_patterns = []

# -- Options for HTML output -------------------------------------------------

# Match the IVPM docs for visual consistency.
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
