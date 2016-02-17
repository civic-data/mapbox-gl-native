{
  'includes': [
    'gyp/common.gypi',
  ],
  'targets': [
    { 'target_name': '<(module_name)',
      'dependencies': [
        'gyp/mbgl.gyp:core',
        'gyp/mbgl.gyp:headless-<(headless_lib)',
      ],

      'include_dirs': [
        'src',
        '<(node_root_dir)/include/node',
        "<!(node -e \"require('nan')\")",
      ],

      'sources': [
        'platform/default/async_task.cpp',
        'platform/default/log_stderr.cpp',
        'platform/default/string_stdlib.cpp',
        'platform/default/run_loop.cpp',
        'platform/default/application_root.cpp',
        'platform/default/thread.cpp',
        'platform/default/image.cpp',
        'platform/default/webp_reader.cpp',
        'platform/default/png_reader.cpp',
        'platform/default/jpeg_reader.cpp',
        'platform/default/timer.cpp',
        'platform/node/src/node_mapbox_gl_native.cpp',
        'platform/node/src/node_log.hpp',
        'platform/node/src/node_log.cpp',
        'platform/node/src/node_map.hpp',
        'platform/node/src/node_map.cpp',
        'platform/node/src/node_request.hpp',
        'platform/node/src/node_request.cpp',
        'platform/node/src/util/async_queue.hpp',
      ],

      'variables': {
        'cflags_cc': [
          '<@(libpng_cflags)',
          '<@(libjpeg-turbo_cflags)',
          '<@(nunicode_cflags)',
          '<@(boost_cflags)',
          '<@(webp_cflags)',
        ],
        'ldflags': [
          '<@(libpng_ldflags)',
          '<@(libjpeg-turbo_ldflags)',
          '<@(nunicode_ldflags)',
          '<@(webp_ldflags)',
        ],
        'libraries': [
          '<@(libpng_static_libs)',
          '<@(libjpeg-turbo_static_libs)',
          '<@(nunicode_static_libs)',
          '<@(webp_static_libs)',
        ],
      },

      'conditions': [
        ['OS == "mac"', {
          'xcode_settings': {
            'OTHER_CPLUSPLUSFLAGS': [ '<@(cflags_cc)' ],
          }
        }, {
          'cflags_cc': [ '<@(cflags_cc)' ],
        }]
      ],

      'link_settings': {
        'conditions': [
          ['OS == "mac"', {
            'libraries': [ '<@(libraries)' ],
            'xcode_settings': { 'OTHER_LDFLAGS': [ '<@(ldflags)' ] }
          }, {
            'libraries': [ '<@(libraries)', '<@(ldflags)' ],
          }]
        ],
      },
    },

    { 'target_name': 'action_after_build',
      'type': 'none',
      'dependencies': [ '<(module_name)' ],
      'copies': [
        {
          'files': [ '<(PRODUCT_DIR)/<(module_name).node' ],
          'destination': '<(module_path)'
        }
      ]
    }
  ]
}
