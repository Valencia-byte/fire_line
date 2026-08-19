/**
 * Parallel Fireline simulation built on top of the supplied FireMap.
 *
 * FireMapParallel extends FireMap and reuses its landscape generation,
 * ignition setup and image output untouched. FireMap.step() is declared
 * final, so it cannot be overridden; instead this class exposes
 * stepParallel(), which replays the same prepareNextState() ->
 * (region update) -> completeStep() sequence as step(), but replaces the
 * single sequential updateRegion() call with a Fork/Join FireTask tree.
 *
 * The sequential cutoff is read from the "fireline.cutoff" system property
 * so it can be tuned for benchmarking without changing the command-line
 * interface, e.g.
 *   java -Dfireline.cutoff=4000 -cp bin FirelineParallel 500 500 17 wildfire ...
 *
 * The ForkJoinPool parallelism level can likewise be tuned without touching
 * the CLI, using the standard JVM property, e.g.
 *   java -Djava.util.concurrent.ForkJoinPool.common.parallelism=4 -cp bin ...
 */
public class FireMapParallel extends FireMap {

    private static final int DEFAULT_SEQUENTIAL_CUTOFF = 1_000;

    private final int sequentialCutoff;

    public FireMapParallel(int rows,
                            int columns,
                            long seed,
                            Mode mode,
                            Landscape landscape,
                            Integer ignitionTopRow,
                            Integer ignitionLeftColumn,
                            Integer ignitionPatchSize) {
        super(rows, columns, seed, mode, landscape,
                ignitionTopRow, ignitionLeftColumn, ignitionPatchSize);
        this.sequentialCutoff = readCutoffFromSystemProperty();
    }

    /**
     * Advances the entire grid by one timestep, using a Fork/Join task tree
     * to update the interior region in parallel. Produces the same result
     * as FireMap.step() for the same starting state.
     */
    public StepResult stepParallel(Mode mode) {
        prepareNextState();

        FireTask rootTask = new FireTask(
                this, mode, 1, getRows() - 1, 1, getColumns() - 1,
                sequentialCutoff);
        rootTask.fork();
        StepResult result = rootTask.join();

        completeStep();
        return result;
    }

    public int getSequentialCutoff() {
        return sequentialCutoff;
    }

    private static int readCutoffFromSystemProperty() {
        String value = System.getProperty("fireline.cutoff");
        if (value == null) {
            return DEFAULT_SEQUENTIAL_CUTOFF;
        }
        return Integer.parseInt(value);
    }
}