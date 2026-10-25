resource "aws_appautoscaling_target" "web" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 2
  max_capacity       = 6
}
resource "aws_appautoscaling_policy" "requests" {
  name               = "${var.group_name}-scale-on-requests"
  service_namespace  = aws_appautoscaling_target.web.service_namespace
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  resource_id        = aws_appautoscaling_target.web.resource_id
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = 60  # requests per minute per task
    scale_out_cooldown = 60  # quick to grow
    scale_in_cooldown  = 300 # slow to shrink

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      # This constructs the exact format AWS expects: app/load-balancer-name/id/target-group-name/id
      resource_label = "${aws_lb.web.arn_suffix}/${aws_lb_target_group.web.arn_suffix}"
    }
  }
}
