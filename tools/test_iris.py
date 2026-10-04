import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import iris as mobile


class MobileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.cap = self.root / 'capacitor'
        (self.cap / 'js').mkdir(parents=True)
        (self.cap / 'node_modules/@capacitor/core').mkdir(parents=True)
        (self.cap / 'package.json').write_text('{"version":"0.2.0"}')
        (self.cap / 'package-lock.json').write_text('{}')
        (self.cap / 'js/bridge.mjs').write_text('export const fixture = true;')
        (self.cap / 'js/register.mjs').write_text('globalThis.mobileFixture = true;')
        self.project = self.root / 'app'
        self.web = self.project / 'public'
        self.web.mkdir(parents=True)
        (self.web / 'index.html').write_text('<main>fixture</main><script src="app.js"></script>')
        (self.web / 'app.css').write_text('body{color:black}')
        (self.project / 'application.js').write_text('globalThis.applicationFixture = true;')
        self.cfg = {'format': 1, 'appId': 'com.example.fixture', 'appName': 'Fixture',
                    'capacitor': '../capacitor', 'webDir': 'public', 'entry': 'application.js',
                    'assets': ['index.html', '*.css']}
        self.save()

    def save(self):
        (self.project / 'iris.mobile.json').write_text(json.dumps(self.cfg))

    def test_build_and_verify_module_bundle(self):
        release = mobile.build(self.project)
        self.assertIn('type="module"', (release / 'index.html').read_text())
        self.assertIn('mobileFixture', (release / 'app.js').read_text())
        self.assertEqual(mobile.built(self.project)[2], release)
        self.assertFalse((self.project / 'node_modules').exists())

    def test_format_two_config_precedes_application_and_binds_csp(self):
        from test_mobile_policy import HTML
        self.cfg.update(format=2, apiOrigin='https://api.example.test'); self.save()
        (self.web / 'index.html').write_text(HTML)
        (self.project / 'application.js').write_text('if(globalThis.IrisMobile.apiOrigin!=="https://api.example.test" || !globalThis.IrisMobileTransport) throw Error("configuration order");')
        release = mobile.build(self.project)
        subprocess.run(['node', str(release / 'app.js')], check=True, timeout=10)
        self.assertIn('connect-src https://api.example.test', (release / 'index.html').read_text())
        self.assertEqual(mobile.built(self.project)[2], release)

    def test_format_two_requires_explicit_secure_configuration(self):
        self.cfg.update(format=2, apiOrigin='http://localhost:8080'); self.save()
        with self.assertRaisesRegex(ValueError, 'HTTPS'):
            mobile.build(self.project)
        self.cfg['apiOrigin'] = 'https://api.example.test'; self.save()
        with self.assertRaisesRegex(ValueError, 'CSP'):
            mobile.build(self.project)

    def test_failed_build_preserves_last_good(self):
        mobile.build(self.project)
        manifest = self.project / '.workspace/mobile/build.json'
        previous = manifest.read_bytes()
        (self.project / 'application.js').write_text('not valid javascript !')
        with self.assertRaises(subprocess.CalledProcessError):
            mobile.build(self.project)
        self.assertEqual(manifest.read_bytes(), previous)
        self.assertEqual(list((self.project / '.workspace/mobile').glob('stage-*')), [])

    def test_stale_source_and_output_tampering_rejected(self):
        release = mobile.build(self.project)
        (self.web / 'app.css').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'stale'):
            mobile.built(self.project)
        (self.web / 'app.css').write_text('body{color:black}')
        (release / 'app.js').write_text('tampered')
        with self.assertRaisesRegex(ValueError, 'integrity'):
            mobile.built(self.project)

    def test_native_plugin_sources_invalidate_a_bundle(self):
        plugin = self.cap / 'native/session-vault'; plugin.mkdir(parents=True)
        (plugin / 'package.json').write_text(json.dumps({'name': '@idris2/capacitor-session-vault', 'version': '0.1.0'}))
        (plugin / 'Vault.swift').write_text('first revision')
        mobile.build(self.project)
        (plugin / 'Vault.swift').write_text('second revision')
        with self.assertRaisesRegex(ValueError, 'stale'):
            mobile.built(self.project)

    def test_directory_symlink_cannot_escape_release(self):
        release = mobile.build(self.project)
        (release / 'outside').symlink_to(self.cap, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlinks'):
            mobile.built(self.project)

    def test_public_symlinks_and_private_assets_rejected(self):
        (self.web / 'app.css').unlink()
        (self.web / 'app.css').symlink_to(self.cap / 'package.json')
        with self.assertRaisesRegex(ValueError, 'Symlinks'):
            mobile.build(self.project)
        (self.web / 'app.css').unlink()
        (self.web / 'private.json').write_text('{"secret":"fixture"}')
        self.cfg['assets'].append('*.json'); self.save()
        with self.assertRaisesRegex(ValueError, 'Only public'):
            mobile.build(self.project)

    def test_configuration_validation(self):
        for key, value in [('format', True), ('entry', '../outside.js'), ('assets', ['../*']), ('appId', 'bad'), ('unknown', True)]:
            original = self.cfg.copy(); self.cfg[key] = value; self.save()
            with self.assertRaises(ValueError):
                mobile.build(self.project)
            self.cfg = original
        (self.project / 'iris.mobile.json').write_text('{"format":1,"format":1}')
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            mobile.build(self.project)

    def test_unknown_workspace_is_not_overwritten(self):
        directory = self.project / '.workspace/mobile'; directory.mkdir(parents=True)
        private = directory / 'keep.txt'; private.write_text('keep')
        with self.assertRaisesRegex(ValueError, 'unowned'):
            mobile.build(self.project)
        self.assertEqual(private.read_text(), 'keep')

    def test_unknown_native_host_is_not_overwritten(self):
        mobile.build(self.project)
        host = self.project / '.workspace/mobile/native'; host.mkdir()
        with self.assertRaisesRegex(ValueError, 'unowned native'):
            mobile.sync(self.project, 'ios')
        self.assertEqual(list(host.iterdir()), [])

    def test_native_sync_is_explicit_and_preserves_identity(self):
        mobile.build(self.project)
        with patch.object(mobile, 'run') as run:
            host, cli = mobile.sync(self.project, 'android')
            self.assertEqual(run.call_count, 3)  # npm ci, cap add, cap sync
            self.assertEqual(run.call_args.args[0][-2:], ['sync', 'android'])
        self.assertEqual(json.loads((host / 'capacitor.config.json').read_text())['webDir'], 'www')
        self.assertEqual(json.loads((host / 'capacitor.config.json').read_text())['loggingBehavior'], 'none')
        self.cfg['appId'] = 'com.example.other'; self.save(); mobile.build(self.project)
        with patch.object(mobile, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'identity'):
                mobile.sync(self.project, 'android')
            run.assert_not_called()
        self.assertEqual(json.loads((host / 'capacitor.config.json').read_text())['appId'], 'com.example.fixture')

    def test_project_lock_rejects_concurrent_native_operations(self):
        with mobile.exclusive(self.project):
            with self.assertRaisesRegex(ValueError, 'Another mobile'):
                with mobile.exclusive(self.project):
                    self.fail('second owner acquired lock')
        with mobile.exclusive(self.project):
            pass

    def test_failed_native_asset_copy_preserves_previous_tree(self):
        mobile.build(self.project)
        with patch.object(mobile, 'run'):
            host, _ = mobile.sync(self.project, 'ios')
        old = (host / 'www/app.js').read_bytes()
        with patch.object(mobile.shutil, 'copytree', side_effect=OSError('copy failed')):
            with self.assertRaisesRegex(OSError, 'copy failed'):
                mobile.sync(self.project, 'ios')
        self.assertEqual((host / 'www/app.js').read_bytes(), old)
        self.assertEqual(list(host.glob('web-stage-*')), [])

    def test_compile_uses_temporary_optional_map(self):
        self.cfg['ui'] = 'mobile.ipkg'; self.save()
        (self.project / 'application.js').unlink()
        (self.project / 'mobile.ipkg').write_text('package fixture\n')
        original = 'collection="nightly-260903"\n[custom.all.fixture]\ntype="local"\npath="."\nipkg="mobile.ipkg"\n'
        (self.project / 'pack.toml').write_text(original)
        locations = []
        def run(args, cwd):
            locations.append(Path(cwd))
            contents = (Path(cwd) / 'pack.toml').read_text()
            self.assertIn('[custom.all.iris-mobile]', contents)
            self.assertIn(str(self.cap), contents)
            self.assertIn('--cg', args)
        with patch.object(mobile, 'run', side_effect=run):
            mobile.compile_ui(self.project)
        self.assertFalse(locations[0].exists())
        self.assertEqual((self.project / 'pack.toml').read_text(), original)

    def test_tool_timeout_stops_owned_process_group(self):
        with patch.object(mobile.mobile_check.subprocess, 'Popen') as popen, \
             patch.object(mobile.mobile_check, 'stop_group') as stop:
            process = popen.return_value
            process.wait.side_effect = subprocess.TimeoutExpired(['fixture'], 300)
            with self.assertRaises(subprocess.TimeoutExpired):
                mobile.run(['fixture'], self.project)
            self.assertTrue(popen.call_args.kwargs['start_new_session'])
            stop.assert_called_once_with(process)

    def test_tool_interrupt_stops_owned_process_group(self):
        with patch.object(mobile.mobile_check.subprocess, 'Popen') as popen, \
             patch.object(mobile.mobile_check, 'stop_group') as stop:
            process = popen.return_value
            process.wait.side_effect = KeyboardInterrupt()
            with self.assertRaises(KeyboardInterrupt):
                mobile.run(['fixture'], self.project)
            stop.assert_called_once_with(process)

    def test_cli_installer_cannot_replace_itself_and_restores_on_failure(self):
        with patch.object(mobile, 'atomic_write') as write:
            mobile.install_cli(mobile.ROOT, force=True)
            write.assert_not_called()
        directory = self.root / 'bin'; directory.mkdir()
        target = directory / 'iris'; target.write_text('old launcher')
        with patch.object(mobile, 'atomic_write', side_effect=OSError('disk full')):
            with self.assertRaises(OSError): mobile.install_cli(directory, force=True)
        self.assertEqual(target.read_text(), 'old launcher')

    def test_cli_installer_refuses_overwrite_unless_backed_up(self):
        directory = self.root / 'bin'; directory.mkdir()
        old = directory / 'iris'; old.write_text('old launcher')
        with self.assertRaisesRegex(ValueError, 'different iris'):
            mobile.install_cli(directory)
        mobile.install_cli(directory, force=True)
        self.assertEqual(next(directory.glob('iris.backup-*')).read_text(), 'old launcher')
        self.assertTrue(os.access(old, os.X_OK))
        self.assertIn(str(mobile.ROOT / 'iris'), old.read_text())


class NewScaffoldTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name).resolve()
        (self.project / 'src').mkdir()
        (self.project / 'src/Demo.idr').write_text('module Demo\n')

    def test_missing_shared_module_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'No Missing.idr'):
            mobile.new_target(self.project, 'web', 'Missing', 'app', 'demo', force=False)

    def test_web_target_uses_detected_sourcedir(self):
        mobile.new_target(self.project, 'web', 'Demo', 'app', 'demo', force=False)
        entry = (self.project / 'src/MainWeb.idr').read_text()
        self.assertIn('import Demo', entry)
        self.assertIn('import Iris.Backend.Web.DOM.Run', entry)
        self.assertIn('main = runWeb app', entry)
        ipkg = (self.project / 'web.ipkg').read_text()
        self.assertIn('sourcedir = "src"', ipkg)
        self.assertIn('executable = demo-web', ipkg)
        self.assertNotIn('prebuild', ipkg)
        html = (self.project / 'index.html').read_text()
        self.assertIn('id="iris-app"', html)
        self.assertIn('src="build/exec/demo-web"', html)

    def test_terminal_target_embeds_this_checkouts_native_source(self):
        mobile.new_target(self.project, 'terminal', 'Demo', 'app', 'demo', force=False)
        ipkg = (self.project / 'terminal.ipkg').read_text()
        self.assertIn(str(mobile.ROOT / 'c/iristui.c'), ipkg)
        self.assertIn('demo-terminal_app', ipkg)

    def test_canvas_target_writes_canvas_mount_and_stylesheet(self):
        mobile.new_target(self.project, 'canvas', 'Demo', 'app', 'demo', force=False)
        html = (self.project / 'canvas.html').read_text()
        self.assertIn('<canvas id="iris-canvas"', html)
        css = (self.project / 'canvas.css').read_text()
        self.assertIn('#iris-canvas', css)

    def test_mobile_target_requires_capacitor_before_writing_anything(self):
        with self.assertRaisesRegex(ValueError, 'requires --capacitor'):
            mobile.new_target(self.project, 'mobile', 'Demo', 'app', 'demo', force=False)
        self.assertEqual(list(self.project.glob('*.ipkg')), [])
        self.assertFalse((self.project / 'src/MainMobile.idr').exists())

    def test_mobile_target_defaults_app_id_without_requiring_it(self):
        capacitor = self.project / 'capacitor'; capacitor.mkdir()
        mobile.new_target(self.project, 'mobile', 'Demo', 'app', 'demo', force=False, capacitor=capacitor)
        cfg = json.loads((self.project / 'iris.mobile.json').read_text())
        self.assertEqual(cfg['appId'], 'com.example.demo')

    def test_default_app_id_handles_unfriendly_names(self):
        self.assertEqual(mobile.default_app_id('my-app'), 'com.example.myapp')
        self.assertEqual(mobile.default_app_id('3d-viewer'), 'com.example.app3dviewer')
        self.assertEqual(mobile.default_app_id('Greeter'), 'com.example.greeter')

    def test_mobile_target_writes_config_matching_documented_schema(self):
        capacitor = self.project / 'capacitor'
        capacitor.mkdir()
        mobile.new_target(self.project, 'mobile', 'Demo', 'app', 'demo', force=False,
                          capacitor=capacitor, app_id='com.example.demo')
        cfg = json.loads((self.project / 'iris.mobile.json').read_text())
        self.assertEqual(cfg['appId'], 'com.example.demo')
        self.assertEqual(cfg['appName'], 'demo')
        self.assertEqual(cfg['capacitor'], str(capacitor.resolve()))
        self.assertEqual(cfg['webDir'], 'public')
        self.assertEqual(cfg['entry'], 'build/exec/demo-mobile')
        self.assertEqual(cfg['ui'], 'mobile.ipkg')
        html = (self.project / 'public/index.html').read_text()
        self.assertIn('<canvas id="iris-canvas">', html)
        self.assertEqual(html.count('<script src="app.js">'), 1)

    def test_refuses_overwrite_without_force(self):
        mobile.new_target(self.project, 'web', 'Demo', 'app', 'demo', force=False)
        with self.assertRaisesRegex(ValueError, 'Refusing to overwrite'):
            mobile.new_target(self.project, 'web', 'Demo', 'app', 'demo', force=False)
        mobile.new_target(self.project, 'web', 'Demo', 'app', 'demo', force=True)


class NewProjectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.origin_patch = patch.object(mobile, 'git_iris_origin', return_value=('https://example.test/iris.git', 'deadbeef'))
        self.origin_patch.start()
        self.addCleanup(self.origin_patch.stop)

    def test_fresh_project_generates_starter_module_config_and_target(self):
        project = self.root / 'greeter'
        mobile.new_project(project, 'greeter', ['web'], 'Greeter', 'app')
        self.assertIn('export\napp : UIApp', (project / 'src/Greeter.idr').read_text())
        toml = (project / 'pack.toml').read_text()
        self.assertIn('url = "https://example.test/iris.git"', toml)
        self.assertIn('commit = "deadbeef"', toml)
        self.assertIn('[custom.all.greeter-web]', toml)
        self.assertTrue((project / 'src/MainWeb.idr').is_file())
        self.assertTrue((project / 'web.ipkg').is_file())
        self.assertTrue((project / 'index.html').is_file())

    def test_multiple_targets_in_one_call(self):
        project = self.root / 'greeter'
        mobile.new_project(project, 'greeter', ['web', 'terminal'], 'Greeter', 'app')
        toml = (project / 'pack.toml').read_text()
        self.assertIn('[custom.all.greeter-web]', toml)
        self.assertIn('[custom.all.greeter-terminal]', toml)
        self.assertTrue((project / 'web.ipkg').is_file())
        self.assertTrue((project / 'terminal.ipkg').is_file())

    def test_refuses_to_recreate_an_existing_project(self):
        project = self.root / 'greeter'
        mobile.new_project(project, 'greeter', ['web'], 'Greeter', 'app')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            mobile.new_project(project, 'greeter', ['canvas'], 'Greeter', 'app')
        # The first run's files are untouched by the refused second call.
        self.assertFalse((project / 'canvas.ipkg').exists())


class NewCliDefaultTargetsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.origin_patch = patch.object(mobile, 'git_iris_origin', return_value=('https://example.test/iris.git', 'deadbeef'))
        self.origin_patch.start()
        self.addCleanup(self.origin_patch.stop)
        self.cwd_patch = patch.object(mobile.Path, 'cwd', return_value=self.root)
        self.cwd_patch.start()
        self.addCleanup(self.cwd_patch.stop)
        self.remembered_patch = patch.object(mobile, 'remembered_capacitor', return_value=None)
        self.remembered_patch.start()
        self.addCleanup(self.remembered_patch.stop)

    def test_bare_new_defaults_to_web_and_mobile(self):
        fake_cap = self.root / 'capacitor'; fake_cap.mkdir()
        with patch.object(mobile, 'default_capacitor', return_value=fake_cap):
            mobile.main(['new', 'greeter'])
        toml = (self.root / 'greeter/pack.toml').read_text()
        self.assertIn('[custom.all.greeter-web]', toml)
        self.assertIn('[custom.all.greeter-mobile]', toml)

    def test_bare_new_falls_back_to_web_only_when_capacitor_unavailable(self):
        with patch.object(mobile, 'default_capacitor', side_effect=OSError('offline')):
            mobile.main(['new', 'greeter'])
        toml = (self.root / 'greeter/pack.toml').read_text()
        self.assertIn('[custom.all.greeter-web]', toml)
        self.assertNotIn('[custom.all.greeter-mobile]', toml)
        self.assertFalse((self.root / 'greeter/mobile.ipkg').exists())

    def test_explicit_target_mobile_propagates_clone_failure_instead_of_falling_back(self):
        with patch.object(mobile, 'default_capacitor', side_effect=OSError('offline')):
            with self.assertRaises(SystemExit):
                mobile.main(['new', 'greeter', '--target', 'mobile'])
        self.assertFalse((self.root / 'greeter').exists())

    def test_new_from_inside_a_same_named_project_refuses_instead_of_nesting(self):
        # Regression: running `new <name>` while already standing inside a
        # project named <name> used to silently create <name>/<name>/
        # (Path.cwd() / name resolved to a path that didn't exist yet, so
        # the "already exists" guard never fired).
        project = self.root / 'greeter'; project.mkdir()
        (project / 'pack.toml').write_text('[custom.all.iris]\n')
        with patch.object(mobile.Path, 'cwd', return_value=project):
            with self.assertRaises(SystemExit):
                mobile.main(['new', 'greeter'])
        self.assertFalse((project / 'greeter').exists())

    def test_explicit_project_overrides_the_same_name_guard(self):
        # --project is an explicit, deliberate override - the guard above
        # only applies when --project was left to its cwd-based default.
        project = self.root / 'greeter'; project.mkdir()
        (project / 'pack.toml').write_text('[custom.all.iris]\n')
        elsewhere = self.root / 'elsewhere'
        with patch.object(mobile.Path, 'cwd', return_value=project):
            with patch.object(mobile, 'default_capacitor', return_value=None):
                mobile.main(['new', 'greeter', '--project', str(elsewhere)])
        self.assertTrue((elsewhere / 'pack.toml').is_file())


class AddTargetsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.origin_patch = patch.object(mobile, 'git_iris_origin', return_value=('https://example.test/iris.git', 'deadbeef'))
        self.origin_patch.start()
        self.addCleanup(self.origin_patch.stop)
        self.project = self.root / 'greeter'
        mobile.new_project(self.project, 'greeter', ['web'], 'Greeter', 'app')
        self.cwd_patch = patch.object(mobile.Path, 'cwd', return_value=self.project)
        self.cwd_patch.start()
        self.addCleanup(self.cwd_patch.stop)

    def test_adds_target_to_current_directory_without_touching_existing_ones(self):
        original = (self.project / 'src/Greeter.idr').read_text()
        mobile.add_targets(['canvas'], 'Greeter', 'app', force=False)
        self.assertEqual((self.project / 'src/Greeter.idr').read_text(), original)
        toml = (self.project / 'pack.toml').read_text()
        self.assertIn('[custom.all.greeter-web]', toml)
        self.assertIn('[custom.all.greeter-canvas]', toml)
        self.assertTrue((self.project / 'canvas.ipkg').is_file())

    def test_cli_layer_defaults_module_to_capitalized_cwd_name(self):
        # No --module: main() must derive 'Greeter' from the cwd ('greeter'),
        # matching the module new_project already generated for this fixture.
        mobile.main(['add', 'canvas'])
        self.assertTrue((self.project / 'canvas.ipkg').is_file())
        self.assertIn('import Greeter', (self.project / 'src/MainCanvas.idr').read_text())

    def test_refuses_without_an_existing_pack_toml(self):
        bare = self.root / 'bare'; bare.mkdir()
        with patch.object(mobile.Path, 'cwd', return_value=bare):
            with self.assertRaisesRegex(ValueError, 'not an iris project'):
                mobile.add_targets(['web'], 'Bare', 'app', force=False)

    def test_rerun_same_target_without_force_fails_cleanly(self):
        with self.assertRaisesRegex(ValueError, 'Refusing to overwrite'):
            mobile.add_targets(['web'], 'Greeter', 'app', force=False)
        mobile.add_targets(['web'], 'Greeter', 'app', force=True)


class CapacitorConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.env_patch = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(self.home)})
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)

    def test_remember_then_recall_round_trips_the_path(self):
        self.assertIsNone(mobile.remembered_capacitor())
        target = self.home / 'capacitor'; target.mkdir()
        mobile.remember_capacitor(target)
        self.assertEqual(mobile.remembered_capacitor(), target)


class DefaultCapacitorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.env_patch = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(self.home / 'config'),
                                                  'XDG_CACHE_HOME': str(self.home / 'cache')})
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)

        def fake_clone(args, **kwargs):
            cache = Path(args[-1])
            (cache / 'js').mkdir(parents=True)
            (cache / 'node_modules/@capacitor/core').mkdir(parents=True)
            (cache / 'package.json').write_text('{"version":"0.3.0"}')
            (cache / 'js/register.mjs').write_text('export const fixture = true;')
            return unittest.mock.Mock(returncode=0)

        self.clone_patch = patch.object(mobile.subprocess, 'run', side_effect=fake_clone)
        self.clone_patch.start()
        self.addCleanup(self.clone_patch.stop)
        self.run_patch = patch.object(mobile, 'run')
        self.run_patch.start()
        self.addCleanup(self.run_patch.stop)

    def test_clones_npm_installs_and_remembers_on_first_call(self):
        cache = self.home / 'cache/iris/capacitor'
        cap = mobile.default_capacitor()
        self.assertEqual(cap, cache)
        mobile.subprocess.run.assert_called_once()
        self.assertIn(mobile.CAPACITOR_URL, mobile.subprocess.run.call_args[0][0])
        self.assertEqual(mobile.run.call_count, 2)
        self.assertEqual(mobile.remembered_capacitor(), cache)

    def test_second_call_reuses_the_cache_without_cloning_again(self):
        mobile.default_capacitor()
        mobile.subprocess.run.reset_mock()
        mobile.run.reset_mock()
        mobile.default_capacitor()
        mobile.subprocess.run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
