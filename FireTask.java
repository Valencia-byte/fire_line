import java.util.concurrent.RecursiveTask;

/**
 * A Fork/Join task that updates one rectangular region of the Fireline grid.
 *
 * Regions are split by rows only. A task whose region is still above the
 * sequential cutoff forks the top half as a new task and computes the
 * bottom half itself, then joins and combines the two reductions. A task
 * at or below the cutoff calls the unmodified serial updateRegion() method
 * directly over its own region.
 *
 * Splitting by rows keeps write regions disjoint (the correctness
 * requirement for lock-free parallel updates) and, since FireMap stores its
 * state as double[rows][columns], means no two sibling tasks ever touch the
 * same row array object.
 */
public class FireTask extends RecursiveTask<FireMap.StepResult> {

    private final FireMap map;
    private final FireMap.Mode mode;
    private final int rowStart;
    private final int rowEnd;
    private final int columnStart;
    private final int columnEnd;
    private final int sequentialCutoff;

    public FireTask(FireMap map,
                     FireMap.Mode mode,
                     int rowStart,
                     int rowEnd,
                     int columnStart,
                     int columnEnd,
                     int sequentialCutoff) {
        this.map = map;
        this.mode = mode;
        this.rowStart = rowStart;
        this.rowEnd = rowEnd;
        this.columnStart = columnStart;
        this.columnEnd = columnEnd;
        this.sequentialCutoff = sequentialCutoff;
    }

    @Override
    protected FireMap.StepResult compute() {
        int rowSpan = rowEnd - rowStart;
        int columnSpan = columnEnd - columnStart;
        long regionCells = (long) rowSpan * (long) columnSpan;

        if (rowSpan <= 1 || regionCells <= sequentialCutoff) {
            return map.updateRegion(mode, rowStart, rowEnd, columnStart, columnEnd);
        }

        int middleRow = rowStart + rowSpan / 2;

        FireTask topTask = new FireTask(
                map, mode, rowStart, middleRow, columnStart, columnEnd,
                sequentialCutoff);
        FireTask bottomTask = new FireTask(
                map, mode, middleRow, rowEnd, columnStart, columnEnd,
                sequentialCutoff);

        topTask.fork();
        FireMap.StepResult bottomResult = bottomTask.compute();
        FireMap.StepResult topResult = topTask.join();

        return FireMap.StepResult.combine(topResult, bottomResult);
    }
}