/* The one graphene symbol the app neuters, and why.
 *
 * The GTK4 backend allocates a graphene point for a view's transform through
 * the bindings, whose handle frees the point AGAIN when the wrapper is
 * collected - and the backend also calls graphene_point_free itself, so every
 * transformed view frees its point twice and the heap is corrupted at the
 * next collection. The pair cannot be separated from the outside; what can be
 * done is to make the EXPLICIT call say nothing and leave the collector's
 * free as the only one.
 *
 * This library defines exactly that one symbol as a no-op and names the real
 * libgraphene as its dependency, so every other graphene call resolved
 * through it falls through to the real thing. LinuxTransforms.cs is the half
 * that points the bindings here.
 */
void graphene_point_free(void *point)
{
    (void)point;
}
