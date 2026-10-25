resource "aws_appautoscaling_target" "web" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 2
  max_capacity       = 6
}
resource "aws_appautoscaling_policy" "requests" {
  name               = "${var.group_name}-scale-on-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 60  # requests per minute per task
    scale_in_cooldown  = 300 # slow to shrink
    scale_out_cooldown = 60  # quick to grow
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      # the ALB and target group, in the form AWS expects
      resource_label = join("/", [
        split("/", aws_lb.web.arn_suffix)[1],
        aws_lb_target_group.web.arn_suffix,
      ])
    }
  }
}
