# design/KIT.md template

Copy this into `design/KIT.md` and fill every section. Numbers come from
the reference (`design-from-app`) or from the user's choices. Write the
reason next to any value that looks odd, so nobody "fixes" it later.

```markdown
# <App> design kit

## Feel
Three words: <calm, precise, warm>. Like <reference app, if any>.

## Tokens

### Palette
| Name | Light | Dark |
| --- | --- | --- |
| gray50 | #F9FBFC | #1E1F22 |
| blue600 | #287ABC | #4C95D3 |

### Meaning
| Token | Palette | Used for |
| --- | --- | --- |
| Ink.text | gray900 / snow | body text |
| Ink.accent | blue600 | selected text, primary buttons, links |
| Ink.selection | blue100 | selected row fill |

### Metric
| Token | Value | Why |
| --- | --- | --- |
| sidebarWidth | 219 | measured |
| rowHeight | 26.5 | measured; the reference runs at 0.77 zoom |

### Motion
| Token | Curve | Used for |
| --- | --- | --- |
| hover | ease out 0.12 s | hover fills |

## Type
| Role | Font | Size | Weight | Used for |
| --- | --- | --- | --- | --- |
| title | system | 20.5 | bold | page titles |
| body | system | 10.75 | regular | task titles |

## Icons
Source: <SF Symbols light / drawn shapes / open set and its license>.
Size <13>, stroke <1.25>, filled when selected: <yes/no>.

## Window
Title bar: <hidden>. Traffic lights at <22, 21.5>, <18.25> apart.
Default size <1000 x 742>. Sidebar: <custom rows / List>.

## Parts

### Sidebar row
Anatomy: icon 13, gap 4.5, label (label role), optional count.
Size: height 26.5, pill inset 9.5, radius 5.
| State | Fill | Text | Icon |
| --- | --- | --- | --- |
| rest | none | text | icon gray |
| hover | hover gray | text | icon gray |
| selected | selection | accent | accent, filled |
| focused | ring accent 2 | text | icon gray |
| disabled | none, 40% | text | icon gray |

### <next part>
...
```
