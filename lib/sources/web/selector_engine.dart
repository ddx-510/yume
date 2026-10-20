import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:xpath_selector/xpath_selector.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

/// Abstracts over the two supported selector languages so the scraping engine
/// doesn't care which a rule uses:
///   - `css`   — CSS selectors (via package:html's querySelector)
///   - `xpath` — XPath selectors (via package:xpath_selector)
///
/// Both are pure string-in/value-out; no network. For a repeated extraction
/// (search results, episodes) call [items] to get per-match [Scope] handles,
/// then [field] within each. For a single value on a whole document (the video
/// pipeline) call [docField].
abstract class SelectorEngine {
  String get type;

  List<Scope> items(String html, String itemSelector);

  /// A field within [scope]. [selector] empty/null means the scope element
  /// itself. [attr] overrides what to read ('text' for text content);
  /// otherwise [fallbackAttr] is used ('text', 'href', 'src', …).
  String? field(
    Scope scope,
    String? selector, {
    String? attr,
    required String fallbackAttr,
  });

  /// A single value anywhere in [html] (used by the extraction pipeline).
  String? docField(
    String html,
    String selector, {
    String? attr,
    String fallbackAttr = 'src',
  });

  static SelectorEngine forType(String type) =>
      type == 'xpath' ? XPathEngine() : CssEngine();

  /// Validates a selector string for this engine; returns an error or null.
  String? validateSelector(String selector);
}

/// Opaque per-match handle returned by [SelectorEngine.items].
abstract class Scope {}

String? _clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

// --- CSS -------------------------------------------------------------------

class CssEngine implements SelectorEngine {
  @override
  String get type => 'css';

  @override
  List<Scope> items(String htmlText, String itemSelector) => html
      .parse(htmlText)
      .querySelectorAll(itemSelector)
      .map(_CssScope.new)
      .toList();

  @override
  String? field(
    Scope scope,
    String? selector, {
    String? attr,
    required String fallbackAttr,
  }) {
    final el = (scope as _CssScope).el;
    final target = (selector == null || selector.isEmpty)
        ? el
        : el.querySelector(selector);
    return target == null ? null : _read(target, attr ?? fallbackAttr);
  }

  @override
  String? docField(
    String htmlText,
    String selector, {
    String? attr,
    String fallbackAttr = 'src',
  }) {
    final target = html.parse(htmlText).querySelector(selector);
    return target == null ? null : _read(target, attr ?? fallbackAttr);
  }

  String? _read(dom.Element el, String attr) {
    if (attr == 'text') return _clean(el.text);
    return _clean(el.attributes[attr] ?? el.attributes['data-$attr']);
  }

  @override
  String? validateSelector(String selector) {
    try {
      dom.Element.html('<div></div>').querySelector(selector);
      return null;
    } catch (e) {
      return 'invalid CSS selector "$selector"';
    }
  }
}

class _CssScope implements Scope {
  _CssScope(this.el);
  final dom.Element el;
}

// --- XPath -----------------------------------------------------------------

class XPathEngine implements SelectorEngine {
  @override
  String get type => 'xpath';

  @override
  List<Scope> items(String htmlText, String itemSelector) =>
      HtmlXPath.node(html.parse(htmlText))
          .query(itemSelector)
          .nodes
          .map(_XPathScope.new)
          .toList();

  @override
  String? field(
    Scope scope,
    String? selector, {
    String? attr,
    required String fallbackAttr,
  }) {
    final node = (scope as _XPathScope).node;
    if (selector == null || selector.isEmpty) {
      if (attr != null && attr != 'text') return _clean(node.attributes[attr]);
      return _clean(node.text);
    }
    final res = node.queryXPath(selector);
    if (attr != null && attr != 'text') {
      return _clean(res.node?.attributes[attr] ?? res.attr);
    }
    // Selector may target an attribute (`.../@href`) → res.attr; else text.
    return _clean(res.attr ?? res.node?.text);
  }

  @override
  String? docField(
    String htmlText,
    String selector, {
    String? attr,
    String fallbackAttr = 'src',
  }) {
    final res = HtmlXPath.node(html.parse(htmlText)).query(selector);
    if (attr != null && attr != 'text') {
      return _clean(res.node?.attributes[attr] ?? res.attr);
    }
    return _clean(res.attr ?? res.node?.text);
  }

  @override
  String? validateSelector(String selector) {
    try {
      HtmlXPath.node(html.parse('<div></div>')).query(selector);
      return null;
    } catch (e) {
      return 'invalid XPath "$selector"';
    }
  }
}

class _XPathScope implements Scope {
  _XPathScope(this.node);
  final XPathNode<dom.Node> node;
}
