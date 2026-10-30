# Sessions

Every cycle needs a **verified 4/4 session**. In that state SmileBASIC runs
the bootstrap and holds an RPC connection, which the host uses to map code.
The host never creates a session by itself inside a cycle. A person sets one
up, and the cycle only checks for it.

Requirements for both platforms: Switch 2 on firmware 23.0.1, SmileBASIC
4.4.9 (or demo 4.4.6 with mac2jb), more than 20 MiB free in its save,
ethernet on the console, and updates blocked.

## Linux

The session runner is an `ns2jb-kurumuz` checkout:

```sh
export HBL_NS2JB=~/ns2jb-kurumuz
cd ~/sw2-sdk
./hbl-start --preflight          # tools, launcher build, runner, 4/4 state
./hbl-start --spawn              # start the runner, then follow the printed steps
```

Wait until the run reports 4/4 verified. After that, `sw2-cycle.sh` finds the
newest run by itself. You can also set `SW2_RUN=$HBL_NS2JB/runs/<run>`
explicitly. HBLauncher's `docs/RECOVERY.md` covers stages that stall.

## macOS (mac2jb)

A Mac can build the SDK itself (`brew install llvm lld glslang spirv-tools`,
then `sh tools/build-all.sh`; see sw2-sdk `docs/SW2.md`), or it can run
prebuilt files without any toolchain:

1. Either build the SDK on the Mac, or build it elsewhere, run
   `sw2 host-bundle`, and copy the tarball over with the frozen candidates.
2. On the Mac, install Node 18+ (mac2jb already ships Node v24). If you
   are using a bundle, run `tar xzf sw2-sdk-host-*.tar.gz`.
3. In mac2jb, start a session with **hold rpc** checked: either the normal
   jailbreak, or *additional tools → run host only*. Wait for 4/4 and a held
   connection. Don't launch MintBrew or HBLauncher from mac2jb, because the
   sw2-sdk host owns the display for the cycle.
4. Find the held **run folder**. It's the folder mac2jb's *rpc already held*
   tool asks for. Pass it to the cycle:

   ```sh
   export SW2_SDK=~/sw2-sdk SW2_RUN=/path/to/held/run SW2_DEDICATED=1
   scripts/sw2-cycle.sh ~/candidates/menu-fix-1
   ```

5. When you're done, use mac2jb's **finish session**, then restart the Switch
   before the next attempt.

> **Not yet proven on hardware:** whether sw2-sdk's host attaches to a run
> folder that mac2jb holds. Both use the same kurumuz RPC layout
> (`shared/rpc.cjs` in the run folder). Run the known-good `hello-cpu`
> candidate as the first macOS cycle, and record the result before you test
> anything else.

## Ending a session

- A clean end: the app returns, the host stops, and the session can host
  another cycle.
- If the host or console stops answering, the session is over. Restart
  SmileBASIC, or the console, and set up a new session. Don't retry into it.
