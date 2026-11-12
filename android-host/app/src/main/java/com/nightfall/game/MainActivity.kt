package com.nightfall.game

import android.app.Activity
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotFragment
import org.godotengine.godot.GodotHost
import org.godotengine.godot.plugin.GodotPlugin

class MainActivity : AppCompatActivity(), GodotHost {

    private var godotFragment: GodotFragment? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val current = supportFragmentManager
            .findFragmentById(R.id.godot_fragment_container)

        godotFragment = if (current is GodotFragment) {
            current
        } else {
            GodotFragment().also { fragment ->
                supportFragmentManager.beginTransaction()
                    .replace(R.id.godot_fragment_container, fragment)
                    .commitNowAllowingStateLoss()
            }
        }
    }

    override fun getActivity(): Activity = this

    override fun getGodot(): Godot? = godotFragment?.godot

    override fun getHostPlugins(godot: Godot): Set<GodotPlugin> = emptySet()
}
