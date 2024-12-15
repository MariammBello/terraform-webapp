// Single IAM user policy with all necessary permissions
resource "aws_iam_user_policy" "terraform_user_policy" {
  name = "terraform_user_policy"
  user = "mariam_altschool"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:PassRole", // Add this line
          "s3:*",         // Change to full S3 access
          "ec2:*"
        ]
        Resource = "*"
      }
    ]
  })
}