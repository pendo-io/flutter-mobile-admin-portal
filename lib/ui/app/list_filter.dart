// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_redux/flutter_redux.dart';
import 'package:invoiceninja_flutter/ui/app/multiselect.dart';
import 'package:invoiceninja_flutter/utils/platforms.dart';
import 'package:redux/redux.dart';

// Project imports:
import 'package:invoiceninja_flutter/constants.dart';
import 'package:invoiceninja_flutter/data/models/entities.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/utils/colors.dart';
import 'package:invoiceninja_flutter/utils/completers.dart';
import 'package:invoiceninja_flutter/utils/formatting.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';
import 'package:invoiceninja_flutter/utils/strings.dart';

class ListFilter extends StatefulWidget {
  const ListFilter({
    Key key,
    @required this.entityType,
    @required this.filter,
    @required this.onFilterChanged,
    @required this.entityIds,
    @required this.onSelectedState,
    this.statuses,
    this.onSelectedStatus,
  }) : super(key: key);

  final EntityType entityType;
  final String filter;
  final Function(String) onFilterChanged;
  final List<String> entityIds;
  final List<EntityStatus> statuses;
  final Function(EntityStatus, bool) onSelectedStatus;
  final Function(EntityState, bool) onSelectedState;

  @override
  _ListFilterState createState() => new _ListFilterState();
}

class _ListFilterState extends State<ListFilter> {
  TextEditingController _filterController;
  FocusNode _focusNode;
  final _debouncer = Debouncer();

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
    _focusNode = FocusNode()..addListener(onFocusChanged);
  }

  void onFocusChanged() {
    // Check is needed to prevent the TextField from
    // refocusing when the users tries to tab out
    if (_focusNode.hasFocus) {
      setState(() {});
    }
  }

  String get _getPlaceholder {
    if (_focusNode.hasFocus) {
      return '';
    }

    final localization = AppLocalization.of(context);
    final count = widget.entityIds.length;

    final isDashboardOrSettings =
        [EntityType.dashboard, EntityType.settings].contains(widget.entityType);
    final isSingle = count == 1 || isDashboardOrSettings;

    final key = toSnakeCase(
        isSingle ? widget.entityType.toString() : widget.entityType.plural);
    final placeholder = localization.lookup(
        widget.entityType == EntityType.dashboard
            ? 'search_company'
            : 'search_$key');

    return isSingle
        ? placeholder
        : placeholder.replaceFirst(
            ':count',
            formatNumber(count.toDouble(), context,
                formatNumberType: FormatNumberType.int));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _filterController.text = widget.filter;

    if (widget.filter != null) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    _focusNode.removeListener(onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context);
    final textColor = Theme.of(context).textTheme.bodyText1.color;
    final isFilterSet = (widget.filter ?? '').isNotEmpty;
    final Store<AppState> store = StoreProvider.of<AppState>(context);
    final state = store.state;
    final enableDarkMode = state.prefState.enableDarkMode;

    final isDashboardOrSettings =
        [EntityType.dashboard, EntityType.settings].contains(widget.entityType);
    final stateFilters =
        state.getListState(widget.entityType).stateFilters.toList();
    final statusFilters =
        state.getListState(widget.entityType).statusFilters.toList();

    Color color;
    if (enableDarkMode) {
      color = convertHexStringToColor(
          isFilterSet ? kDefaultDarkBorderColor : kDefaultDarkBorderColor);
    } else {
      color = convertHexStringToColor(
          isFilterSet ? kDefaultLightBorderColor : kDefaultLightBorderColor);
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              padding: const EdgeInsets.only(left: 8.0),
              height: 40,
              margin: EdgeInsets.only(bottom: 2.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.all(Radius.circular(kBorderRadius)),
              ),
              child: TextField(
                focusNode: _focusNode,
                textAlign:
                    _filterController.text.isNotEmpty || _focusNode.hasFocus
                        ? TextAlign.start
                        : TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(left: 8, right: 8, bottom: 6),
                  suffixIcon: _filterController.text.isNotEmpty ||
                          _focusNode.hasFocus
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: textColor,
                          ),
                          onPressed: () {
                            _filterController.text = '';
                            _focusNode.unfocus(
                                disposition:
                                    UnfocusDisposition.previouslyFocusedChild);
                            widget.onFilterChanged(null);
                          },
                        )
                      : Icon(Icons.search, color: textColor),
                  border: InputBorder.none,
                  hintText: _getPlaceholder,
                ),
                autocorrect: false,
                onChanged: (value) {
                  _debouncer.run(() {
                    widget.onFilterChanged(value);
                  });
                },
                controller: _filterController,
              ),
            ),
          ),
        ),
        if (isDesktop(context) && !isDashboardOrSettings) ...[
          SizedBox(width: 8),
          Flexible(
            child: DropDownMultiSelect(
                onChanged: (List<dynamic> selected) {
                  final stateFilters = state
                      .getListState(widget.entityType)
                      .stateFilters
                      .toList();

                  final added =
                      selected.where((dynamic e) => !stateFilters.contains(e));
                  final removed =
                      stateFilters.where((dynamic e) => !selected.contains(e));

                  for (var state in added) {
                    widget.onSelectedState(state, true);
                  }
                  for (var state in removed) {
                    widget.onSelectedState(state, false);
                  }
                },
                options: EntityState.values.toList(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                ),
                selectedValues: stateFilters,
                whenEmpty: localization.all,
                menuItembuilder: (dynamic value) {
                  final state = value as EntityState;
                  return Text(
                    localization.lookup(state.name),
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  );
                },
                childBuilder: (selected) {
                  return Align(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          selected.isNotEmpty
                              ? selected
                                  .map<String>((dynamic value) => localization
                                      .lookup((value as EntityState).name))
                                  .join(', ')
                              : localization.all,
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                      alignment: Alignment.centerLeft);
                }),
          ),
          if (widget.statuses != null) ...[
            SizedBox(width: 8),
            Flexible(
              child: DropDownMultiSelect(
                  onChanged: (List<dynamic> selected) {
                    final statusFilters = state
                        .getListState(widget.entityType)
                        .statusFilters
                        .toList();

                    final added = selected.where((dynamic e) => !statusFilters
                        .map((e) => e.id)
                        .toList()
                        .contains((e as EntityStatus).id));

                    final removed = statusFilters.where((dynamic e) => !selected
                        .map<String>((dynamic e) => e.id)
                        .toList()
                        .contains((e as EntityStatus).id));

                    for (var status in added) {
                      widget.onSelectedStatus(status, true);
                    }

                    for (var status in removed) {
                      widget.onSelectedStatus(status, false);
                    }
                  },
                  options: widget.statuses,
                  selectedValues: statusFilters,
                  whenEmpty: localization.all,
                  menuItembuilder: (dynamic value) {
                    final state = value as EntityStatus;
                    return Text(
                      localization.lookup(state.name),
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                    );
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  ),
                  childBuilder: (selected) {
                    return Align(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            selected.isNotEmpty
                                ? selected
                                    .map((dynamic value) =>
                                        (value as EntityStatus).name)
                                    .join(', ')
                                : localization.all,
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                        alignment: Alignment.centerLeft);
                  }),
            ),
          ],
        ],
      ],
    );
  }
}
