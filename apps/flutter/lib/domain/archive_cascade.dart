/// How archiving a goal or project treats linked children.
enum ArchiveCascade {
  /// Soft-archive the parent only. Children keep FKs; active lists hide
  /// work that sits under an archived project.
  parentOnly,

  /// Goal only: also soft-archive every non-archived project under the goal.
  withProjects,

  /// Clear parent FKs on children, then archive the parent.
  detachChildren,

  /// Project only: archive the project and soft-archive its open tasks.
  withOpenTasks,
}
