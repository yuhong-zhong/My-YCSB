REDIS_ROOT=~/yuhong/redis
MY_YCSB_ROOT=~/yuhong/My-YCSB/build
MM_MEAUSRE_ROOT=~/yuhong/mm-measure/build
PERF_ROOT=~/yuhong/linux/tools/perf
LOG_ROOT=~/yuhong/exp_log

# setup redis config
sudo sysctl vm.overcommit_memory=1
sudo bash -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
sudo bash -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"

# create log folder
mkdir -p $LOG_ROOT

# run experiment
for color in 768 16 8 7 6 5 4
do
        printf "[*] Running experiment with color %d\n" $color
        # kill redis
        while [ -n "$(pgrep redis)" ]
        do
            kill $(pgrep redis)
        done
        printf "[*] Redis killed\n"

        # fill color
        $MM_MEAUSRE_ROOT/init_colormem 163840
        printf "[*] Color refilled\n"

        # start redis
        (numactl --cpunodebind 0  --membind 0 $MM_MEAUSRE_ROOT/colorctl 768 $color 0 $REDIS_ROOT/src/redis-server $REDIS_ROOT/redis.conf) &
        printf "[*] Redis restarted\n"

        sleep 5

        # run init
        numactl --cpunodebind 1 --membind 1 $MY_YCSB_ROOT/init_redis $MY_YCSB_ROOT/../redis/config.yaml
        printf "[*] Redis initialized\n"

        # start perf
        (sleep 5 && (($PERF_ROOT/perf stat -e unc_m_tagchk.hit,unc_m_tagchk.miss_clean,unc_m_tagchk.miss_dirty --per-node sleep 5) | tee $LOG_ROOT/${color}_perf.log)) &
        printf "[*] Perf started\n"
        
        # run workload
        (numactl --cpunodebind 1 --membind 1 $MY_YCSB_ROOT/run_redis $MY_YCSB_ROOT/../redis/config.yaml) | tee $LOG_ROOT/${color}_run.log
done