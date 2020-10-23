import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/ui/app/presenters/entity_presenter.dart';
import 'package:invoiceninja_flutter/utils/formatting.dart';

class ProjectPresenter extends EntityPresenter {
  static List<String> getDefaultTableFields(UserCompanyEntity userCompany) {
    return [
      ProjectFields.name,
      ProjectFields.client,
      ProjectFields.taskRate,
      ProjectFields.dueDate,
      ProjectFields.publicNotes,
      ProjectFields.privateNotes,
      ProjectFields.budgetedHours,
      EntityFields.state,
    ];
  }

  static List<String> getAllTableFields(UserCompanyEntity userCompany) {
    return [
      ...getDefaultTableFields(userCompany),
      ...EntityPresenter.getBaseFields(),
      ProjectFields.number,
      ProjectFields.clientId,
      ProjectFields.customValue1,
      ProjectFields.customValue2,
      ProjectFields.customValue3,
      ProjectFields.customValue4,
      ProjectFields.updatedAt,
      ProjectFields.archivedAt,
      ProjectFields.isDeleted,
      ProjectFields.documents,
    ];
  }

  @override
  Widget getField({String field, BuildContext context}) {
    final project = entity as ProjectEntity;
    final state = StoreProvider.of<AppState>(context).state;

    switch (field) {
      case ProjectFields.name:
        return Text(project.name);
      case ProjectFields.client:
      case ProjectFields.clientId:
        return Text(state.clientState.get(project.clientId).displayName);
      case ProjectFields.taskRate:
        return Text(formatNumber(project.taskRate, context));
      case ProjectFields.dueDate:
        return Text(formatDate(project.dueDate, context));
      case ProjectFields.publicNotes:
        return Text(project.publicNotes ?? '');
      case ProjectFields.privateNotes:
        return Text(project.privateNotes ?? '');
      case ProjectFields.budgetedHours:
        return Text(formatNumber(project.budgetedHours, context,
            formatNumberType: FormatNumberType.double));
      case ProjectFields.number:
        return Text(project.number ?? '');
      case ProjectFields.customValue1:
        return Text(project.customValue1);
      case ProjectFields.customValue2:
        return Text(project.customValue2);
      case ProjectFields.customValue3:
        return Text(project.customValue3);
      case ProjectFields.customValue4:
        return Text(project.customValue4);
      case ProjectFields.updatedAt:
        return Text(formatDate(
            convertTimestampToDateString(project.updatedAt), context));
      case ProjectFields.archivedAt:
        return Text(formatDate(
            convertTimestampToDateString(project.archivedAt), context));
      case ProjectFields.isDeleted:
        return Text(project.isDeleted.toString());
      case ProjectFields.documents:
        return Text('${project.documents.length}');
    }

    return super.getField(field: field, context: context);
  }
}
