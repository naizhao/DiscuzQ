import 'package:discuzq/utils/appConfigurations.dart';
import 'package:discuzq/widgets/common/discuzIcon.dart';
import 'package:discuzq/widgets/common/discuzListTile.dart';
import 'package:discuzq/widgets/common/discuzText.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:flutter/material.dart';

import 'package:discuzq/models/appModel.dart';

///
/// notice: 使用SettingSwitcher 进行设置的选项，值必须是bool，否则将出错
///
class SettingSwitcher extends StatelessWidget {
  final String settinKey;
  final IconData icon;
  final String label;

  const SettingSwitcher(
      {@required this.settinKey, @required this.icon, @required this.label});
  @override
  Widget build(BuildContext context) => ScopedModelDescendant<AppModel>(
      rebuildOnChange: false,
      builder: (context, child, model) => Container(
            child: DiscuzListTile(
                leading: DiscuzIcon(icon),
                title: DiscuzText(label),
                trailing: Switch.adaptive(
                  value: model.appConf[settinKey],
                  onChanged: (bool val) => AppConfigurations().update(
                      context: context,
                      key: 'darkTheme',
                      value: !model.appConf['darkTheme']),
                )),
          ));
}
