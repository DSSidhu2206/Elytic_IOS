// lib/frontend/animations/join_animations/join_avatar_animation.dart

import 'package:flutter/material.dart';

class JoinAvatarAnimation extends StatefulWidget {
  final String userId;
  final Offset position;
  final double size;
  final Widget avatar;
  final bool alreadyAnimated;
  final VoidCallback onAnimationComplete;

  const JoinAvatarAnimation({
    Key? key,
    required this.userId,
    required this.position,
    required this.size,
    required this.avatar,
    required this.alreadyAnimated,
    required this.onAnimationComplete,
  }) : super(key: key);

  @override
  _JoinAvatarAnimationState createState() => _JoinAvatarAnimationState();
}

class _JoinAvatarAnimationState extends State<JoinAvatarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState(){
    super.initState();
    if(widget.alreadyAnimated){
      WidgetsBinding.instance.addPostFrameCallback((_)=>widget.onAnimationComplete());
      return;
    }
    _ctrl = AnimationController(vsync:this,duration:const Duration(milliseconds:800));
    _scale = CurvedAnimation(parent:_ctrl,curve:Curves.elasticOut);
    _ctrl.addStatusListener((s){
      if(s==AnimationStatus.completed) widget.onAnimationComplete();
    });
    _ctrl.forward();
  }

  @override
  void dispose(){
    if(!widget.alreadyAnimated) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    if(widget.alreadyAnimated){
      return Positioned(
        left:widget.position.dx,
        top:widget.position.dy,
        child:SizedBox(width:widget.size,height:widget.size,child:widget.avatar),
      );
    }
    return AnimatedBuilder(
      animation:_scale,
      builder:(c,_)=>Positioned(
        left:widget.position.dx + widget.size*(1-_scale.value)/2,
        top:widget.position.dy + widget.size*(1-_scale.value)/2,
        child:Transform.scale(
          scale:_scale.value,
          child:SizedBox(width:widget.size,height:widget.size,child:widget.avatar),
        ),
      ),
    );
  }
}
