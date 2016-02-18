#include "../fixtures/util.hpp"

#include <mbgl/map/map.hpp>
#include <mbgl/platform/default/headless_view.hpp>
#include <mbgl/platform/default/headless_display.hpp>
#include <mbgl/storage/online_file_source.hpp>
#include <mbgl/util/run_loop.hpp>

using namespace mbgl;

TEST(Map, DoubleStyleLoad) {
    util::RunLoop runLoop;
    std::shared_ptr<HeadlessDisplay> display = std::make_shared<HeadlessDisplay>();
    HeadlessView view(display, 1, 512, 512);
    OnlineFileSource fileSource;

    Map map(view, fileSource);
    map.setStyleJSON("", "");
    map.setStyleJSON("", "");
}
