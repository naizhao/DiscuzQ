import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:discuzq/models/threadModel.dart';
import 'package:discuzq/models/threadVideoModel.dart';
import 'package:discuzq/widgets/threads/threadsCacher.dart';
import 'package:discuzq/router/route.dart';
import 'package:discuzq/widgets/player/discuzPlayer.dart';
import 'package:discuzq/models/postModel.dart';

///
/// 显示视频缩略图的组件
class ThreadVideoSnapshot extends StatelessWidget {
  ///------------------------------
  /// threadsCacher 是用于缓存当前页面的主题数据的对象
  /// 当数据更新的时候，数据会存储到 threadsCacher
  /// threadsCacher 在页面销毁的时候，务必清空 .clear()
  ///
  final ThreadsCacher threadsCacher;

  ///
  /// 主题
  ///
  final ThreadModel thread;

  ///
  /// 关联的帖子或评论
  final PostModel post;

  ThreadVideoSnapshot(
      {@required this.threadsCacher,
      @required this.thread,
      @required this.post});

  @override
  Widget build(BuildContext context) {
    ///
    /// 先获取视频信息
    /// 这个主题不包含任何的视频，所以直接返回
    ///
    if (thread.relationships.threadVideo == null) {
      return const SizedBox();
    }

    /// 查找视频ID
    final int threadVideoID =
        int.tryParse(thread.relationships.threadVideo['data']['id']);
    if (threadVideoID == 0) {
      return const SizedBox();
    }

    /// 查找视频
    /// 找不到对应的视频就放弃渲染
    /// todo: 应该提醒用户视频丢失
    final List<ThreadVideoModel> videos = threadsCacher.videos
        .where((ThreadVideoModel v) => v.id == threadVideoID)
        .toList();
    if (videos == null || videos.length == 0) {
      return const SizedBox();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
          margin: const EdgeInsets.only(top: 10),
          child: _videoContainer(context: context, video: videos[0])),
    );
  }

  ///
  /// 生成视频缩图
  ///
  Widget _videoContainer({BuildContext context, ThreadVideoModel video}) =>
      GestureDetector(
        onTap: () => DiscuzRoute.open(
            context: context,
            fullscreenDialog: true,
            widget: DiscuzPlayer(
              video: video,
              post: post,
            )),
        child: Container(
          alignment: Alignment.center,
          height: 180,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.all(
              const Radius.circular(5),
            ),
          ),
          child: Container(
            child: Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.center,
              children: <Widget>[
                CachedNetworkImage(
                  imageUrl: video.attributes.coverUrl,
                  fit: BoxFit.cover,
                ),
                Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: Image.asset(
                        'assets/images/play.png',
                        width: 40,
                        height: 40,
                      ),
                      onPressed: () => DiscuzRoute.open(
                          context: context,
                          fullscreenDialog: true,
                          widget: DiscuzPlayer(
                            video: video,
                            post: post,
                          )),
                    )),
              ],
            ),
          ),
        ),
      );
}
