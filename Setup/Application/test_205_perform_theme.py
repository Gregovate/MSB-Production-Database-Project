"""#205 theme contrast: Python-only checks of shipped CSS and banner tokens."""
from pathlib import Path
import re
import pytest

APP = Path(__file__).parent


def palette(text):
    return dict(re.findall(r'(--[\w-]+):\s*(#[0-9a-fA-F]{6})',text))


def luminance(color):
    rgb = [int(color[i:i+2],16)/255 for i in (1,3,5)]
    linear = [v/12.92 if v <= 0.04045 else ((v+0.055)/1.055)**2.4 for v in rgb]
    return sum(v*w for v,w in zip(linear,(0.2126,0.7152,0.0722)))


@pytest.mark.parametrize('mode',['light','dark','system-dark'])
def test_perform_theme_contrast(mode):
    css = (APP/'setup.css').read_text()
    theme = (APP/'setup_theme.css').read_text()
    colors = palette(re.search(r':root\s*\{([^}]+)\}',css).group(1))
    if mode != 'light':
        pattern = (r'html\[data-theme="dark"\]\s*\{([^}]+)\}' if mode == 'dark'
                   else r'html:not\(\[data-theme="light"\]\)\s*\{([^}]+)\}')
        colors.update(palette(re.search(pattern,theme).group(1)))
    for foreground, background in [('--text','--card'),('--warning','--warning-soft'),('--success','--success-soft')]:
        a,b = luminance(colors[foreground]),luminance(colors[background])
        ratio = (max(a,b)+0.05)/(min(a,b)+0.05)
        assert ratio >= 4.5, f'{mode} {foreground}/{background}: {ratio:.2f}:1'


def test_perform_banners_use_the_verified_theme_pairs():
    source = (APP/'setup_next_pass.js').read_text()
    daily = source.split('const color = overloaded ? ',1)[1].split('})()}',1)[0]
    assert 'background:var(--card, #fff);color:var(--text, #18212b)' in daily
    assert '--surface' not in daily
    shift = source.split('function nextPerformWorkloadLabel(',1)[1].split('// Count each crew',1)[0]
    assert "warning ? 'var(--warning, #9a5a00)' : 'var(--success, #277a43)'" in shift
    assert "warning ? 'var(--warning-soft, #fff4df)' : 'var(--success-soft, #eaf6ee)'" in shift
    assert 'background:${background};color:${color}' in shift
