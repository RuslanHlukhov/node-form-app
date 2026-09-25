moved {
  from = aws_security_group.alb_sg
  to   = module.security.aws_security_group.alb_sg
}

moved {
  from = aws_security_group.app_sg
  to   = module.security.aws_security_group.app_sg
}

moved {
  from = aws_security_group.db_sg
  to   = module.security.aws_security_group.db_sg
}

moved {
  from = aws_s3_bucket.app_images
  to   = module.storage.aws_s3_bucket.app_images
}

moved {
  from = aws_iam_role.ec2_s3_role
  to   = module.iam.aws_iam_role.ec2_s3_role
}

moved {
  from = aws_iam_role_policy.s3_access_policy
  to   = module.iam.aws_iam_role_policy.s3_access_policy
}

moved {
  from = aws_iam_instance_profile.ec2_profile
  to   = module.iam.aws_iam_instance_profile.ec2_profile
}

moved {
  from = aws_db_subnet_group.db_subnet_group
  to   = module.database.aws_db_subnet_group.db_subnet_group
}

moved {
  from = aws_db_instance.postgres
  to   = module.database.aws_db_instance.postgres
}

moved {
  from = aws_lb.app_alb
  to   = module.alb.aws_lb.app_alb
}

moved {
  from = aws_lb_target_group.app_tg
  to   = module.alb.aws_lb_target_group.app_tg
}

moved {
  from = aws_lb_listener.web
  to   = module.alb.aws_lb_listener.web
}

moved {
  from = data.aws_ami.ubuntu
  to   = module.compute.data.aws_ami.ubuntu
}

moved {
  from = aws_launch_template.app_lt
  to   = module.compute.aws_launch_template.app_lt
}

moved {
  from = aws_autoscaling_group.app_asg
  to   = module.compute.aws_autoscaling_group.app_asg
}